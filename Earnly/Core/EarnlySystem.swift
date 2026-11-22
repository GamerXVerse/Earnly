import Foundation

/// Single writer for one local file. Publish state only after its durable commit succeeds.
public actor EarnlySystem: PracticeSessionManaging, RewardManaging, ProfilePersisting {
    private let file: LocalStateFile
    private let questions: any QuestionProviding
    private let now: @Sendable () -> Date
    private let provenance: DataProvenance
    private var state: LocalState

    public init(
        fileURL: URL,
        questions: any QuestionProviding = DemoQuestions(),
        provenance: DataProvenance,
        now: @escaping @Sendable () -> Date = Date.init
    ) throws {
        let file = LocalStateFile(url: fileURL)
        var state = try file.load()
        // Approval is time-sensitive. Refresh it from the adapter after each launch.
        // .unavailable preserves the last known approval until the adapter checks it.
        if state.lifecycle.authorization == .approved {
            state.lifecycle.authorization = .unavailable
            awaitingAuthorizationRefresh = true
        }
        self.file = file
        self.questions = questions
        self.provenance = provenance
        self.now = now
        self.state = state
    }

    private var awaitingAuthorizationRefresh = false

    public func dashboard() -> DashboardSnapshot {
        let lifecycle = state.lifecycle
        return DashboardSnapshot(
            authorization: lifecycle.authorization,
            restriction: lifecycle.displayState,
            policy: state.policy,
            selection: lifecycle.needsSelectionRefresh ? nil : state.selection,
            studyProfile: state.profile,
            activeSession: lifecycle.stage.activeSessionID.flatMap { state.sessions[$0] },
            earnedMinutes: .available(state.ledger.totalEarnedMinutes, provenance: provenance),
            mostRecentThresholdMinutes: lifecycle.lastThreshold.map {
                .available($0.thresholdMinutes, provenance: provenance)
            } ?? .unavailable,
            remainingMinutes: .unavailable,
            provenance: provenance
        )
    }

    public func studyProfile() -> StudyProfile { state.profile }
    public func rewardLedger() -> RewardLedger { state.ledger }
    public func currentCycle() -> UsageCycle? { state.lifecycle.stage.cycle }

    func completedSessionAwaitingCredit() -> UUID? {
        switch state.lifecycle.stage {
        case let .pending(_, sessionID): return sessionID
        case let .pausedReward(sessionID) where state.ledger.transactions[sessionID] == nil: return sessionID
        default: return nil
        }
    }

    func isAwaitingAccessRelease(cycleID: UUID) -> Bool {
        guard case let .releasing(cycle) = state.lifecycle.stage else { return false }
        return cycle.id == cycleID
    }
    public func pendingOperation() -> RestrictionOperation? { state.lifecycle.operation(selection: state.selection) }

    public func saveStudyProfile(_ profile: StudyProfile) throws {
        var next = state
        next.profile = profile
        try commit(next)
    }

    /// Set the user's preferred initial duration before any activities are configured.
    func setUnconfiguredAllowance(_ allowance: InitialAllowance) throws {
        guard state.lifecycle.stage.cycle == nil else { throw LifecycleError.configurationLocked }
        var next = state
        next.policy = try ScreenTimePolicy(
            initialAllowance: allowance, requiredQuestions: state.policy.requiredQuestions,
            rewardedMinutes: state.policy.rewardedMinutes, isEnabled: state.policy.isEnabled
        )
        try commit(next)
    }

    /// Configure a fresh initial allowance. Reset the previous configuration before replacing it.
    @discardableResult
    public func configure(policy: ScreenTimePolicy, selection: ActivitySelection) throws -> UsageCycle {
        try requireAuthorization()
        guard policy.isEnabled else { throw LifecycleError.disabledPolicy }
        guard selection.isValid else { throw LifecycleError.invalidSelection }
        var next = state
        let cycle: UsageCycle
        switch state.lifecycle.stage {
        case .unconfigured:
            cycle = UsageCycle(id: UUID(), thresholdMinutes: policy.initialAllowance.rawValue, rewardSessionID: nil)
            next.lifecycle.stage = .installing(cycle)
        case let .pausedReward(sessionID):
            guard let session = state.sessions[sessionID] else { throw PracticeError.unknownSession }
            if let credit = state.ledger.transactions[sessionID] {
                cycle = UsageCycle(id: UUID(), thresholdMinutes: credit.earnedMinutes, rewardSessionID: sessionID)
                next.lifecycle.stage = .installing(cycle)
            } else {
                cycle = UsageCycle(id: UUID(), thresholdMinutes: policy.initialAllowance.rawValue, rewardSessionID: nil)
                next.lifecycle.stage = .pending(cycle, sessionID: session.id)
            }
            next.lifecycle.needsShieldReconciliation = true
        default:
            throw LifecycleError.configurationLocked
        }
        next.policy = policy
        next.selection = selection
        try commit(next)
        return cycle
    }

    /// Validate before starting platform cleanup under the coordinator's serialization.
    public func checkConfigurationReset() throws {
        switch state.lifecycle.stage {
        case .pending, .pausedReward: throw LifecycleError.configurationLocked
        default: break
        }
        switch state.lifecycle.stage {
        case let .installing(cycle), let .releasing(cycle):
            guard cycle.rewardSessionID == nil else { throw LifecycleError.configurationLocked }
        default: break
        }
    }

    /// Call after stopping monitoring and clearing the Earnly-owned store. History survives.
    /// Earned rewards in flight are preserved until activated.
    public func resetConfiguration(policy: ScreenTimePolicy? = nil) throws {
        try checkConfigurationReset()
        var next = state
        next.lifecycle.stage = .unconfigured
        next.lifecycle.failure = nil
        next.lifecycle.needsSelectionRefresh = false
        next.lifecycle.needsShieldReconciliation = false
        next.selection = nil
        if let policy { next.policy = policy }
        try commit(next)
    }

    /// Persist an explicit user disablement while retaining any completed, unactivated reward.
    func pauseScreenTime() throws {
        var next = state
        switch state.lifecycle.stage {
        case let .pending(_, sessionID), let .pausedReward(sessionID):
            next.lifecycle.stage = .pausedReward(sessionID: sessionID)
        case let .installing(cycle), let .releasing(cycle):
            next.lifecycle.stage = cycle.rewardSessionID.map { .pausedReward(sessionID: $0) } ?? .unconfigured
        default:
            next.lifecycle.stage = .unconfigured
        }
        next.policy = try ScreenTimePolicy(
            initialAllowance: state.policy.initialAllowance, requiredQuestions: state.policy.requiredQuestions,
            rewardedMinutes: state.policy.rewardedMinutes, isEnabled: false
        )
        next.selection = nil
        next.lifecycle.failure = nil
        next.lifecycle.needsSelectionRefresh = false
        next.lifecycle.needsShieldReconciliation = false
        try commit(next)
    }

    /// Rebind a suspended lifecycle and prepare to reapply any previously required shield.
    public func replaceRevokedSelection(_ selection: ActivitySelection) throws {
        guard state.lifecycle.authorization == .approved else {
            throw LifecycleError.authorizationRequired(state.lifecycle.authorization)
        }
        guard selection.isValid else { throw LifecycleError.invalidSelection }
        guard state.lifecycle.needsSelectionRefresh, let old = state.lifecycle.stage.cycle else {
            throw LifecycleError.invalidTransition
        }
        let cycle = UsageCycle(id: UUID(), thresholdMinutes: old.thresholdMinutes, rewardSessionID: old.rewardSessionID)
        var next = state
        switch state.lifecycle.stage {
        case .installing, .releasing:
            next.lifecycle.stage = .installing(cycle)
            next.lifecycle.needsShieldReconciliation = cycle.rewardSessionID != nil
        case .available:
            // Reissuing an active reward could double spend it. Reconfiguration is explicit.
            throw LifecycleError.configurationLocked
        case .shielding:
            next.lifecycle.stage = .shielding(cycle)
        case .restricted:
            next.lifecycle.stage = .restricted(cycle)
            next.lifecycle.needsShieldReconciliation = true
        case let .practicing(_, sessionID):
            next.lifecycle.stage = .practicing(cycle, sessionID: sessionID)
            next.lifecycle.needsShieldReconciliation = true
        case let .pending(_, sessionID):
            next.lifecycle.stage = .pending(cycle, sessionID: sessionID)
            next.lifecycle.needsShieldReconciliation = true
        case .unconfigured, .pausedReward:
            throw LifecycleError.invalidTransition
        }
        next.selection = selection
        next.lifecycle.failure = nil
        next.lifecycle.needsSelectionRefresh = false
        try commit(next)
    }

    public func retryPendingOperation() throws {
        guard let cycle = state.lifecycle.stage.cycle, state.lifecycle.failure != nil else {
            throw LifecycleError.invalidTransition
        }
        try handle(.retry(cycleID: cycle.id))
    }

    public func handle(_ event: RestrictionEvent) throws {
        try handle(event, at: now())
    }

    public func receiveThreshold(_ event: UsageThresholdEvent) throws {
        try handle(.thresholdReached(cycleID: event.cycleID), at: event.reachedAt)
    }

    private func handle(_ event: RestrictionEvent, at date: Date) throws {
        var next = state
        if case let .authorizationChanged(status) = event, awaitingAuthorizationRefresh,
           status != .approved && status != .unavailable {
            next.lifecycle.authorization = .approved
        }
        // Keep the approved value on disk during transient refresh failures. After a relaunch
        // it is needed to detect an actual revocation and invalidate old selection IDs.
        if event == .authorizationChanged(.unavailable) {
            if state.lifecycle.authorization == .approved {
                state.lifecycle.authorization = .unavailable
                awaitingAuthorizationRefresh = true
                return
            }
            if awaitingAuthorizationRefresh { return }
        }
        try next.lifecycle.handle(event, ledger: &next.ledger, now: date)
        try commit(next)
        if case .authorizationChanged = event { awaitingAuthorizationRefresh = false }
    }

    public func startPractice() throws -> PracticeSession {
        try requireAuthorization()
        if case let .practicing(_, sessionID) = state.lifecycle.stage { return try session(id: sessionID) }
        guard case let .restricted(cycle) = state.lifecycle.stage else { throw LifecycleError.invalidTransition }
        let required = state.policy.requiredQuestions
        let selected = try questions.questions(for: state.profile, count: required)
        guard selected.count >= required else {
            throw PracticeError.insufficientQuestions(required: required, available: selected.count)
        }
        let session = try PracticeSession(id: UUID(), startedAt: now(),
                                          questions: Array(selected.prefix(required)), policy: state.policy)
        var next = state
        next.sessions[session.id] = session
        next.lifecycle.stage = .practicing(cycle, sessionID: session.id)
        try commit(next)
        return session
    }

    public func session(id: UUID) throws -> PracticeSession {
        guard let session = state.sessions[id] else { throw PracticeError.unknownSession }
        return session
    }

    public func submitAnswer(sessionID: UUID, questionID: String, answerID: String) throws -> PracticeSession {
        var session = try session(id: sessionID)
        if session.isComplete {
            try session.submit(questionID: questionID, answerID: answerID, at: now())
            return session
        }
        try requireAuthorization()
        guard case let .practicing(cycle, activeID) = state.lifecycle.stage, activeID == sessionID else {
            throw LifecycleError.invalidTransition
        }
        let submittedAt = max(session.attempts.last?.submittedAt ?? session.startedAt, now())
        try session.submit(questionID: questionID, answerID: answerID, at: submittedAt)
        var next = state
        next.sessions[sessionID] = session
        if session.isComplete {
            next.lifecycle.stage = .pending(cycle, sessionID: sessionID)
        }
        try commit(next)
        return session
    }

    public func grantReward(for sessionID: UUID) throws -> RewardTransaction {
        if let credit = state.ledger.transactions[sessionID] { return credit }
        let session = try session(id: sessionID)
        guard let completedAt = session.completedAt else { throw PracticeError.incompleteSession }
        guard state.lifecycle.stage.activeSessionID == sessionID else { throw LifecycleError.invalidTransition }
        switch state.lifecycle.stage {
        case .pending, .pausedReward: break
        default: throw LifecycleError.invalidTransition
        }

        guard !state.ledger.totalEarnedMinutes.addingReportingOverflow(session.rewardMinutes).overflow else {
            throw RewardError.ledgerCapacityExceeded
        }
        let credit = RewardTransaction(sessionID: sessionID, earnedMinutes: session.rewardMinutes,
                                       earnedAt: max(completedAt, now()))
        let cycle = UsageCycle(id: UUID(), thresholdMinutes: credit.earnedMinutes, rewardSessionID: sessionID)
        var next = state
        next.ledger.transactions[sessionID] = credit
        if case .pending = next.lifecycle.stage {
            next.lifecycle.stage = .installing(cycle)
        }
        try commit(next)
        return credit
    }

    private func requireAuthorization() throws {
        let authorization = state.lifecycle.authorization
        guard authorization == .approved else { throw LifecycleError.authorizationRequired(authorization) }
        guard !state.lifecycle.needsSelectionRefresh, !state.lifecycle.needsShieldReconciliation else {
            throw LifecycleError.invalidTransition
        }
    }

    private func commit(_ next: LocalState) throws {
        guard next != state else { return }
        var durable = next
        if awaitingAuthorizationRefresh, next.lifecycle.authorization == .unavailable {
            durable.lifecycle.authorization = .approved
        }
        guard durable.isValid else { throw PersistenceError.invalidState }
        try file.save(durable)
        state = next
    }
}
