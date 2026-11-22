import Foundation

struct Lifecycle: Codable, Equatable, Sendable {
    enum Stage: Codable, Equatable, Sendable {
        case unconfigured
        case pausedReward(sessionID: UUID)
        case installing(UsageCycle)
        case releasing(UsageCycle)
        case available(UsageCycle)
        case shielding(UsageCycle)
        case restricted(UsageCycle)
        case practicing(UsageCycle, sessionID: UUID)
        case pending(UsageCycle, sessionID: UUID)

        var cycle: UsageCycle? {
            switch self {
            case .unconfigured, .pausedReward: nil
            case let .installing(cycle), let .releasing(cycle), let .available(cycle),
                 let .shielding(cycle), let .restricted(cycle), let .practicing(cycle, _),
                 let .pending(cycle, _): cycle
            }
        }

        var activeSessionID: UUID? {
            switch self {
            case let .practicing(_, sessionID), let .pending(_, sessionID), let .pausedReward(sessionID): sessionID
            case let .installing(cycle), let .releasing(cycle): cycle.rewardSessionID
            default: nil
            }
        }
    }

    var stage: Stage = .unconfigured
    var authorization: AuthorizationState = .notDetermined
    var failure: RestrictionFailure?
    var lastThreshold: UsageCycle?
    var needsSelectionRefresh = false
    var needsShieldReconciliation = false

    var displayState: RestrictionState {
        guard authorization == .approved || stage == .unconfigured && authorization == .notDetermined else {
            return .authorizationUnavailable(authorization)
        }
        if needsSelectionRefresh { return .selectionRequired }
        if let failure { return .failed(failure) }
        if needsShieldReconciliation { return .applyingShield }
        switch stage {
        case .unconfigured, .pausedReward: return .unconfigured
        case let .installing(cycle), let .releasing(cycle):
            if let sessionID = cycle.rewardSessionID { return .rewardPending(sessionID: sessionID) }
            return .configuring
        case let .available(cycle): return .available(cycle)
        case .shielding: return .applyingShield
        case .restricted: return .restricted
        case let .practicing(_, sessionID): return .practiceInProgress(sessionID: sessionID)
        case let .pending(_, sessionID): return .rewardPending(sessionID: sessionID)
        }
    }

    func operation(selection: ActivitySelection?) -> RestrictionOperation? {
        guard authorization == .approved, !needsSelectionRefresh, failure == nil, let selection else { return nil }
        if needsShieldReconciliation, let cycle = stage.cycle {
            return .applyShield(cycleID: cycle.id, selection: selection)
        }
        switch stage {
        case let .installing(cycle): return .installMonitoring(cycle: cycle, selection: selection)
        case let .releasing(cycle): return .releaseShield(cycleID: cycle.id)
        case let .shielding(cycle): return .applyShield(cycleID: cycle.id, selection: selection)
        default: return nil
        }
    }

    mutating func handle(_ event: RestrictionEvent, ledger: inout RewardLedger, now: Date) throws {
        switch event {
        case let .authorizationChanged(status):
            if authorization == .approved && status != .approved && stage != .unconfigured {
                needsSelectionRefresh = true
            }
            if (authorization == .approved || authorization == .revoked)
                && (status == .notDetermined || status == .denied) {
                authorization = .revoked
            } else {
                authorization = status
            }
        case let .monitoringInstalled(id):
            guard let cycle = try activeCycle(id) else { return }
            guard stage != .releasing(cycle), stage != .available(cycle) else { return }
            guard stage == .installing(cycle), failure == nil, !needsShieldReconciliation else {
                throw LifecycleError.invalidTransition
            }
            stage = .releasing(cycle)
        case let .accessReleased(id):
            guard let cycle = try activeCycle(id) else { return }
            guard stage != .available(cycle) else { return }
            guard stage == .releasing(cycle), failure == nil else { throw LifecycleError.invalidTransition }
            if let sessionID = cycle.rewardSessionID {
                guard var credit = ledger.transactions[sessionID], credit.activatedAt == nil else {
                    throw LifecycleError.missingCredit
                }
                credit.activatedAt = max(credit.earnedAt, now)
                ledger.transactions[sessionID] = credit
            }
            stage = .available(cycle)
        case let .thresholdReached(id):
            guard stage.cycle?.id == id, !needsSelectionRefresh, let cycle = stage.cycle else { return }
            guard authorization == .approved else { throw LifecycleError.authorizationRequired(authorization) }
            if needsShieldReconciliation { return }
            if stage == .installing(cycle) || stage == .releasing(cycle) {
                guard failure != .monitoringInterrupted else { return }
                failure = .thresholdBeforeRelease
                return
            }
            guard stage == .available(cycle), failure != .monitoringInterrupted else { return }
            if let sessionID = cycle.rewardSessionID {
                guard var credit = ledger.transactions[sessionID], let activatedAt = credit.activatedAt else {
                    throw LifecycleError.missingCredit
                }
                credit.thresholdReachedAt = max(activatedAt, now)
                ledger.transactions[sessionID] = credit
            }
            lastThreshold = cycle
            stage = .shielding(cycle)
        case let .shieldApplied(id):
            guard let cycle = try activeCycle(id) else { return }
            guard failure == nil else { throw LifecycleError.invalidTransition }
            if needsShieldReconciliation {
                needsShieldReconciliation = false
                return
            }
            switch stage {
            case .shielding: stage = .restricted(cycle)
            case .restricted, .practicing, .pending: return
            default: throw LifecycleError.invalidTransition
            }
        case let .operationFailed(id, reason):
            guard try activeCycle(id) != nil else { return }
            if reason == .monitoringInterrupted {
                switch stage {
                case .available, .installing, .releasing:
                    failure = .monitoringInterrupted
                    return
                default:
                    throw LifecycleError.invalidTransition
                }
            }
            let expected: RestrictionFailure
            switch stage {
            case .installing: expected = needsShieldReconciliation ? .shield : .monitoring
            case .releasing, .shielding: expected = .shield
            case .restricted, .practicing, .pending:
                guard needsShieldReconciliation else { throw LifecycleError.invalidTransition }
                expected = .shield
            default: throw LifecycleError.invalidTransition
            }
            guard reason == expected else { throw LifecycleError.invalidTransition }
            if failure == nil { failure = reason }
        case let .retry(id):
            guard let cycle = try activeCycle(id) else { return }
            guard failure != .monitoringInterrupted else { throw LifecycleError.configurationLocked }
            if failure == .thresholdBeforeRelease {
                stage = .installing(.init(id: UUID(), thresholdMinutes: cycle.thresholdMinutes,
                                          rewardSessionID: cycle.rewardSessionID))
            }
            failure = nil
        }
    }

    private func activeCycle(_ id: UUID) throws -> UsageCycle? {
        guard let cycle = stage.cycle, cycle.id == id else { return nil }
        guard authorization == .approved else { throw LifecycleError.authorizationRequired(authorization) }
        guard !needsSelectionRefresh else { throw LifecycleError.invalidTransition }
        return cycle
    }
}
