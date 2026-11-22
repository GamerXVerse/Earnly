import Foundation

public enum NativeMonitoringStatus: Equatable, Sendable {
    case unconfigured
    case pending
    case registered(UsageCycle)
    case shielded
    case interrupted
    case cleanupPending
    case unavailable
}

public struct NativeDashboard: Equatable, Sendable {
    public let dashboard: DashboardSnapshot
    public let monitoring: NativeMonitoringStatus
    /// A credited reward is at the release step, including when the latest release failed.
    public let rewardReleasePending: Bool
}

/// The coordinator is the only host writer for platform operations. The App Group lock
/// coordinates those operations with the Device Activity Monitor process.
actor ScreenTimeCoordinator {
    private let system: EarnlySystem
    private let authorization: any ScreenTimeAuthorizing
    private let platform: GenerationScreenTime
    private var commandInProgress = false

    init(system: EarnlySystem, authorization: any ScreenTimeAuthorizing, platform: GenerationScreenTime) {
        self.system = system
        self.authorization = authorization
        self.platform = platform
    }

    func dashboard() async -> NativeDashboard {
        let dashboard = await system.dashboard()
        let monitoring: NativeMonitoringStatus
        if let record = try? platform.journal.read() {
            if record.retiring {
                monitoring = .cleanupPending
            } else if dashboard.authorization != .approved {
                monitoring = .unavailable
            } else {
                switch dashboard.restriction {
                case let .available(cycle):
                    if let active = record.registration, active.cycleID == cycle.id, let selection = record.selection,
                       active.threshold == nil, !active.expired, platform.now() < active.end,
                       active.releaseConfirmed,
                       (try? platform.backend.contains(active, selection: selection)) == true,
                       platform.backend.shieldStatus() == .clear {
                        monitoring = .registered(cycle)
                    } else {
                        monitoring = .interrupted
                    }
                case .restricted, .practiceInProgress:
                    monitoring = platform.backend.shieldStatus() == .applied ? .shielded : .interrupted
                case .configuring, .applyingShield, .rewardPending: monitoring = .pending
                case .failed: monitoring = .interrupted
                case .unconfigured, .selectionRequired: monitoring = .unconfigured
                case .authorizationUnavailable: monitoring = .unavailable
                }
            }
        } else {
            monitoring = .unavailable
        }
        let rewardReleasePending: Bool
        if let cycle = await system.currentCycle(), cycle.rewardSessionID != nil {
            rewardReleasePending = await system.isAwaitingAccessRelease(cycleID: cycle.id)
        } else {
            rewardReleasePending = false
        }
        return NativeDashboard(dashboard: dashboard, monitoring: monitoring, rewardReleasePending: rewardReleasePending)
    }

    func requestAuthorization() async throws -> AuthorizationState {
        try beginCommand()
        defer { commandInProgress = false }
        do {
            _ = try await authorization.requestAuthorization()
        } catch {
            try await reconcileAuthorization()
            throw error
        }
        try await reconcileAuthorization()
        return await system.dashboard().authorization
    }

    func activate() async throws {
        try beginCommand()
        defer { commandInProgress = false }
        try await reconcileAuthorization()
        if let sessionID = await system.completedSessionAwaitingCredit() {
            _ = try await system.grantReward(for: sessionID)
        }
        guard await system.dashboard().authorization == .approved else { return }
        if try platform.journal.read().retiring {
            try await disableWhileHoldingCommand()
            return
        }
        try await drive()
    }

    func configure(policy: ScreenTimePolicy, selection: StoredActivitySelection) async throws {
        try beginCommand()
        defer { commandInProgress = false }
        guard policy.isEnabled else { throw LifecycleError.disabledPolicy }
        try await reconcileAuthorization()
        let dashboard = await system.dashboard()
        guard dashboard.authorization == .approved else {
            throw LifecycleError.authorizationRequired(dashboard.authorization)
        }

        if dashboard.restriction == .selectionRequired {
            try platform.retire(clearSelection: true)
            try platform.prepareSelection(selection)
            do {
                try await system.replaceRevokedSelection(selection.summary)
            } catch LifecycleError.configurationLocked {
                // A revoked, previously open allowance cannot be resumed with the old tokens.
                try await system.pauseScreenTime()
                try await system.configure(policy: policy, selection: selection.summary)
            }
        } else {
            if await system.currentCycle() != nil || (try? platform.journal.read().retiring) == true {
                try await disableWhileHoldingCommand()
            }
            try platform.prepareSelection(selection)
            try await system.configure(policy: policy, selection: selection.summary)
        }
        try await drive()
    }

    func finishPractice(sessionID: UUID) async throws -> RewardTransaction {
        try beginCommand()
        defer { commandInProgress = false }
        // The private state verifies completion and commits the sole credit before any effect.
        _ = try await system.grantReward(for: sessionID)
        try await reconcileAuthorization()
        if await system.dashboard().authorization == .approved,
           !(try platform.journal.read().retiring) {
            try await drive()
        }
        return try await system.grantReward(for: sessionID)
    }

    func retry() async throws {
        try beginCommand()
        defer { commandInProgress = false }
        if try platform.journal.read().retiring {
            try await disableWhileHoldingCommand()
            return
        }
        try await reconcileAuthorization()
        if case .failed = await system.dashboard().restriction {
            try await system.retryPendingOperation()
        }
        try await drive()
    }

    func disable() async throws {
        try beginCommand()
        defer { commandInProgress = false }
        try await disableWhileHoldingCommand()
    }

    private func disableWhileHoldingCommand() async throws {
        try platform.retire(clearSelection: true, leaveFence: true)
        try await system.pauseScreenTime()
        try platform.finishRetirement(clearSelection: true)
    }

    private func beginCommand() throws {
        guard !commandInProgress else { throw ScreenTimeServiceError.operationInProgress }
        commandInProgress = true
    }

    private func reconcileAuthorization() async throws {
        let status = await authorization.authorizationState()
        try await system.handle(.authorizationChanged(status))
        let reconciled = await system.dashboard().authorization
        if reconciled == .revoked || reconciled == .denied {
            let record = try? platform.journal.read()
            if record == nil || record?.registration != nil || record?.selection != nil || record?.retiring == true {
                try platform.retire(clearSelection: true)
            }
        }
    }

    private func drive() async throws {
        // Every successful effect advances a finite sequence. New callbacks can add one
        // shield operation but cannot grant a credit or start another allowance.
        for _ in 0..<6 {
            try await reconcileRegistration()
            guard let operation = await system.pendingOperation() else { return }
            switch operation {
            case let .installMonitoring(cycle, selection):
                try await perform(.monitoring, cycleID: cycle.id) {
                    try platform.install(cycle: cycle, selection: selection)
                }
                try await system.handle(.monitoringInstalled(cycleID: cycle.id))
            case let .releaseShield(cycleID):
                try await perform(.shield, cycleID: cycleID) { try platform.release(cycleID: cycleID) }
                try await system.handle(.accessReleased(cycleID: cycleID))
            case let .applyShield(cycleID, selection):
                try await perform(.shield, cycleID: cycleID) {
                    try platform.apply(selection: selection, cycleID: cycleID)
                }
                try await system.handle(.shieldApplied(cycleID: cycleID))
            }
        }
        throw LifecycleError.invalidTransition
    }

    private func perform(_ failure: RestrictionFailure, cycleID: UUID, effect: () throws -> Void) async throws {
        do {
            try effect()
        } catch ScreenTimeServiceError.earlyThreshold {
            try await reconcileRegistration()
            throw ScreenTimeServiceError.earlyThreshold
        } catch ScreenTimeServiceError.monitoringInterrupted {
            try await interrupt(cycleID: cycleID)
            throw ScreenTimeServiceError.monitoringInterrupted
        } catch {
            try await system.handle(.operationFailed(cycleID: cycleID, failure))
            throw error
        }
    }

    private func reconcileRegistration() async throws {
        guard let cycle = await system.currentCycle() else { return }
        let dashboard = await system.dashboard()
        guard dashboard.authorization == .approved else { return }
        let record = try platform.journal.read()
        guard !record.retiring else { return }
        guard let active = record.registration, active.cycleID == cycle.id, let selection = record.selection else {
            if case .available = dashboard.restriction { try await interrupt(cycleID: cycle.id) }
            return
        }

        if let threshold = active.threshold {
            // The store effect and journal confirmation can precede the host commit.
            // A bare intent does not prove the shield was released.
            if active.releaseRequested, !active.releaseConfirmed,
               await system.isAwaitingAccessRelease(cycleID: cycle.id) {
                try platform.reconcileThresholdShield(cycleID: cycle.id)
                try await system.handle(.operationFailed(cycleID: cycle.id, .monitoringInterrupted))
                try platform.acknowledge(cycleID: cycle.id)
                return
            }
            if active.releaseConfirmed, await system.isAwaitingAccessRelease(cycleID: cycle.id) {
                if dashboard.restriction == .failed(.shield) { try await system.retryPendingOperation() }
                if await system.pendingOperation() == .releaseShield(cycleID: cycle.id) {
                    try await system.handle(.accessReleased(cycleID: cycle.id))
                }
            }
            if !active.thresholdAcknowledged { try await system.receiveThreshold(threshold) }
            if platform.backend.shieldStatus() != .applied || !active.thresholdAcknowledged {
                try platform.reconcileThresholdShield(cycleID: cycle.id)
            }
            if await system.pendingOperation() == .applyShield(cycleID: cycle.id, selection: selection.summary) {
                try await system.handle(.shieldApplied(cycleID: cycle.id))
            }
            if !active.thresholdAcknowledged { try platform.acknowledge(cycleID: cycle.id) }
            return
        }

        if active.expired || platform.now() >= active.end {
            try await interrupt(cycleID: cycle.id)
        } else if case .available = dashboard.restriction,
                  try !platform.backend.contains(active, selection: selection) {
            try await interrupt(cycleID: cycle.id)
        }
    }

    private func interrupt(cycleID: UUID) async throws {
        try await system.handle(.operationFailed(cycleID: cycleID, .monitoringInterrupted))
        if let active = try platform.journal.read().registration, active.cycleID == cycleID {
            try platform.expire(activity: active.name)
        } else if let selection = await system.dashboard().selection {
            try platform.apply(selection: selection, cycleID: cycleID)
        }
    }
}
