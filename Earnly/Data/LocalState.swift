import Foundation

struct LocalState: Codable, Equatable, Sendable {
    static let currentVersion = 1
    private(set) var version: Int = Self.currentVersion
    var profile = StudyProfile()
    var policy = ScreenTimePolicy.standard
    var selection: ActivitySelection?
    var lifecycle = Lifecycle()
    var sessions: [UUID: PracticeSession] = [:]
    var ledger = RewardLedger()

    enum CodingKeys: String, CodingKey {
        case version, profile, policy, selection, lifecycle, sessions, ledger
    }

    var isValid: Bool {
        guard selection?.isValid != false,
              sessions.allSatisfy({ $0.key == $0.value.id && $0.value.isValid }),
              ledger.transactions.allSatisfy({ key, credit in
                  guard key == credit.sessionID, let session = sessions[key],
                        let completedAt = session.completedAt,
                        credit.earnedMinutes == session.rewardMinutes, credit.earnedAt >= completedAt else {
                      return false
                  }
                  if let activated = credit.activatedAt, activated < credit.earnedAt { return false }
                  if let reached = credit.thresholdReachedAt {
                      guard let activated = credit.activatedAt, reached >= activated else { return false }
                  }
                  return true
              }) else { return false }

        guard ledger.hasValidTotal else { return false }
        let unactivatedRewardID: UUID?
        switch lifecycle.stage {
        case let .installing(cycle), let .releasing(cycle):
            unactivatedRewardID = cycle.rewardSessionID
        default:
            unactivatedRewardID = nil
        }
        guard ledger.transactions.values.allSatisfy({
            $0.activatedAt != nil || $0.sessionID == unactivatedRewardID
        }) else { return false }

        if let cycle = lifecycle.stage.cycle {
            guard selection != nil, policy.isEnabled, validCycle(cycle) else { return false }
        } else {
            guard selection == nil, lifecycle.failure == nil, !lifecycle.needsSelectionRefresh else { return false }
        }
        if let last = lifecycle.lastThreshold {
            guard validCycle(last), last.rewardSessionID.map({
                ledger.transactions[$0]?.thresholdReachedAt != nil
            }) != false else { return false }
        }

        if lifecycle.needsShieldReconciliation {
            switch lifecycle.stage {
            case .installing, .restricted, .practicing, .pending: break
            default: return false
            }
        }
        if let failure = lifecycle.failure {
            switch (lifecycle.stage, failure) {
            case (.installing, .monitoring), (.installing, .thresholdBeforeRelease),
                 (.releasing, .thresholdBeforeRelease), (.releasing, .shield), (.shielding, .shield): break
            case (.installing, .shield), (.restricted, .shield), (.practicing, .shield), (.pending, .shield):
                guard lifecycle.needsShieldReconciliation else { return false }
            default: return false
            }
        }

        switch lifecycle.stage {
        case .unconfigured:
            return true
        case let .installing(cycle), let .releasing(cycle):
            return cycle.rewardSessionID.map {
                ledger.transactions[$0]?.activatedAt == nil && ledger.transactions[$0] != nil
            } ?? true
        case let .available(cycle):
            return cycle.rewardSessionID.map {
                ledger.transactions[$0]?.activatedAt != nil && ledger.transactions[$0]?.thresholdReachedAt == nil
            } ?? true
        case let .shielding(cycle), let .restricted(cycle):
            return cycle.rewardSessionID.map { ledger.transactions[$0]?.thresholdReachedAt != nil } ?? true
        case let .practicing(cycle, sessionID):
            return validPracticeCycle(cycle) && sessions[sessionID]?.isComplete == false
        case let .pending(cycle, sessionID):
            return validPracticeCycle(cycle) && sessions[sessionID]?.isComplete == true
                && ledger.transactions[sessionID] == nil
        }
    }

    private func validCycle(_ cycle: UsageCycle) -> Bool {
        guard cycle.thresholdMinutes > 0 else { return false }
        if let sessionID = cycle.rewardSessionID {
            return ledger.transactions[sessionID]?.earnedMinutes == cycle.thresholdMinutes
        }
        return InitialAllowance(rawValue: cycle.thresholdMinutes) != nil
    }

    private func validPracticeCycle(_ cycle: UsageCycle) -> Bool {
        cycle.rewardSessionID.map { ledger.transactions[$0]?.thresholdReachedAt != nil } ?? true
    }
}
