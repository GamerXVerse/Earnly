import Foundation
import Testing
@testable import EarnlySystems

struct LifecycleTests {
    @Test func rewardAndShieldFinishIndependentlyWithIdempotentRetries() async throws {
        let fixture = TestFixture()
        defer { fixture.remove() }
        let system = try fixture.system()
        let initial = try await fixture.restrict(system)
        #expect(await system.dashboard().restriction == .restricted)
        try await system.handle(.thresholdReached(cycleID: initial.id))
        let started = try await system.startPractice()
        #expect(try await system.startPractice().id == started.id)
        await #expect(throws: PracticeError.incompleteSession) {
            try await system.grantReward(for: started.id)
        }

        let first = started.questions[0]
        let firstAnswer = try #require(first.options.first { $0.id != first.correctAnswerID })
        let progress = try await system.submitAnswer(sessionID: started.id, questionID: first.id, answerID: firstAnswer.id)
        #expect(progress.answeredQuestions == 1)
        #expect(!progress.isComplete)
        let second = started.questions[1]
        let secondAnswer = try #require(second.options.first { $0.id != second.correctAnswerID })
        let completed = try await system.submitAnswer(sessionID: started.id, questionID: second.id, answerID: secondAnswer.id)
        #expect(completed.completedAt == fixture.date)
        #expect(completed.correctAnswers == 0)
        #expect(try await system.submitAnswer(sessionID: started.id, questionID: second.id,
                                              answerID: secondAnswer.id) == completed)
        #expect(await system.dashboard().restriction == .rewardPending(sessionID: started.id))
        await #expect(throws: LifecycleError.configurationLocked) { try await system.checkConfigurationReset() }

        async let firstCredit = system.grantReward(for: started.id)
        async let secondCredit = system.grantReward(for: started.id)
        let (credit, repeated) = try await (firstCredit, secondCredit)
        #expect(credit == repeated)
        #expect(credit.earnedMinutes == 7)
        #expect(credit.activatedAt == nil)
        let pending = await system.pendingOperation()
        guard case let .installMonitoring(cycle, _) = pending else {
            Issue.record("Expected monitoring registration")
            return
        }
        #expect(cycle.thresholdMinutes == 7)
        try await system.handle(.monitoringInstalled(cycleID: cycle.id))
        try await system.handle(.operationFailed(cycleID: cycle.id, .shield))
        #expect(await system.dashboard().restriction == .failed(.shield))
        #expect(await system.pendingOperation() == nil)
        #expect(await system.rewardLedger().transactions[started.id]?.activatedAt == nil)

        try await system.retryPendingOperation()
        try await system.handle(.accessReleased(cycleID: cycle.id))
        try await system.handle(.accessReleased(cycleID: cycle.id))
        try await system.handle(.thresholdReached(cycleID: initial.id))
        #expect(await system.dashboard().restriction == .available(cycle))
        #expect(await system.dashboard().remainingMinutes == .unavailable)

        try await system.handle(.thresholdReached(cycleID: cycle.id))
        try await system.handle(.thresholdReached(cycleID: cycle.id))
        try await system.handle(.shieldApplied(cycleID: cycle.id))
        let ledger = await system.rewardLedger()
        #expect(ledger.totalEarnedMinutes == 7)
        #expect(try await system.grantReward(for: started.id).consumedAtLeastMinutes == 7)
        #expect(await system.dashboard().mostRecentThresholdMinutes == .available(7, provenance: .simulated))
    }

    @Test func invalidTransitionsAndEarlyThresholdRecovery() async throws {
        let fixture = TestFixture()
        defer { fixture.remove() }
        let system = try fixture.system()
        await #expect(throws: LifecycleError.authorizationRequired(.notDetermined)) {
            try await system.configure(policy: .standard, selection: fixture.selection)
        }
        try await system.handle(.authorizationChanged(.approved))
        await #expect(throws: LifecycleError.invalidSelection) {
            try await system.configure(policy: .standard, selection: ActivitySelection(
                id: UUID(), applicationCount: 0, categoryCount: 0, webDomainCount: 0
            ))
        }
        let cycle = try await system.configure(policy: .standard, selection: fixture.selection)
        await #expect(throws: LifecycleError.invalidTransition) {
            try await system.handle(.accessReleased(cycleID: cycle.id))
        }
        await #expect(throws: LifecycleError.invalidTransition) { try await system.startPractice() }
        await #expect(throws: LifecycleError.configurationLocked) {
            try await system.configure(policy: .standard, selection: fixture.selection)
        }
        try await system.handle(.operationFailed(cycleID: cycle.id, .monitoring))
        #expect(await system.dashboard().restriction == .failed(.monitoring))
        try await system.retryPendingOperation()
        try await system.handle(.thresholdReached(cycleID: cycle.id))
        #expect(await system.dashboard().restriction == .failed(.thresholdBeforeRelease))
        try await system.retryPendingOperation()
        guard case let .installMonitoring(newCycle, _) = await system.pendingOperation() else {
            Issue.record("Expected a replacement generation")
            return
        }
        #expect(cycle.id != newCycle.id)
        try await system.handle(.thresholdReached(cycleID: cycle.id))
        try await system.handle(.monitoringInstalled(cycleID: newCycle.id))
        try await system.handle(.accessReleased(cycleID: newCycle.id))
        #expect(await system.dashboard().restriction == .available(newCycle))
    }

    @Test func authorizationAndSelectionRecovery() async throws {
        let fixture = TestFixture()
        defer { fixture.remove() }
        let simulated = SimulatedScreenTime(authorization: .denied)
        await #expect(throws: ScreenTimeServiceError.denied) { try await simulated.requestAuthorization() }
        await simulated.setAuthorization(.notDetermined)
        await simulated.failNext(.authorization)
        await #expect(throws: ScreenTimeServiceError.requestFailed) { try await simulated.requestAuthorization() }
        #expect(try await simulated.requestAuthorization() == .approved)
        try await simulated.saveSelection(fixture.selection)

        let system = try fixture.system()
        _ = try await fixture.restrict(system)
        let started = try await system.startPractice()
        try await system.handle(.authorizationChanged(.revoked))
        #expect(await system.dashboard().restriction == .authorizationUnavailable(.revoked))
        #expect(await system.dashboard().selection == nil)
        try await system.handle(.authorizationChanged(.approved))
        #expect(await system.dashboard().restriction == .selectionRequired)
        let replacement = ActivitySelection(id: UUID(), applicationCount: 0, categoryCount: 1, webDomainCount: 0)
        try await system.replaceRevokedSelection(replacement)
        #expect(await system.dashboard().restriction == .applyingShield)
        await #expect(throws: LifecycleError.invalidTransition) { try await system.startPractice() }
        guard case let .applyShield(cycleID, selection) = await system.pendingOperation() else {
            Issue.record("Expected a shield reconciliation")
            return
        }
        await simulated.setAuthorization(.revoked)
        await simulated.setAuthorization(.approved)
        try await simulated.saveSelection(replacement)
        try await simulated.applyShield(for: selection, cycleID: cycleID)
        try await system.handle(.shieldApplied(cycleID: cycleID))
        #expect(try await system.startPractice().id == started.id)
    }

    @Test func completedPracticeCanBeCreditedWhileAuthorizationIsRevoked() async throws {
        let fixture = TestFixture()
        defer { fixture.remove() }
        let system = try fixture.system()
        _ = try await fixture.restrict(system)
        let session = try await system.startPractice()
        for question in session.questions {
            _ = try await system.submitAnswer(sessionID: session.id, questionID: question.id,
                                              answerID: question.correctAnswerID)
        }
        try await system.handle(.authorizationChanged(.revoked))
        let credit = try await system.grantReward(for: session.id)
        #expect(credit.activatedAt == nil)
        #expect(await system.pendingOperation() == nil)
        try await system.handle(.authorizationChanged(.approved))
        try await system.replaceRevokedSelection(fixture.selection)
        guard case let .applyShield(cycleID, _) = await system.pendingOperation() else {
            Issue.record("Expected the reward to wait for a new shield")
            return
        }
        try await system.handle(.operationFailed(cycleID: cycleID, .shield))
        try await system.retryPendingOperation()
        try await system.handle(.shieldApplied(cycleID: cycleID))
        guard case let .installMonitoring(cycle, _) = await system.pendingOperation() else {
            Issue.record("Expected the pending reward registration")
            return
        }
        try await system.handle(.monitoringInstalled(cycleID: cycle.id))
        try await system.handle(.accessReleased(cycleID: cycle.id))
        #expect(try await system.grantReward(for: session.id).activatedAt == fixture.date)
        #expect(await system.rewardLedger().transactions.count == 1)
    }

    @Test func disabledConfigurationRetiresItsGeneration() async throws {
        let fixture = TestFixture()
        defer { fixture.remove() }
        let system = try fixture.system()
        let old = try await fixture.restrict(system)
        let disabled = try ScreenTimePolicy(initialAllowance: .fifteen, isEnabled: false)
        try await system.resetConfiguration(policy: disabled)
        await #expect(throws: LifecycleError.disabledPolicy) {
            try await system.configure(policy: disabled, selection: fixture.selection)
        }
        try await system.handle(.thresholdReached(cycleID: old.id))
        let dashboard = await system.dashboard()
        #expect(dashboard.restriction == .unconfigured)
        #expect(dashboard.policy == disabled)
        #expect(dashboard.selection == nil)
    }

    @Test func simulatorDeliversExplicitThresholdAndSupportsInjectedErrors() async throws {
        let fixture = TestFixture()
        defer { fixture.remove() }
        let system = try fixture.system()
        let platform = SimulatedScreenTime(authorization: .approved)
        try await platform.saveSelection(fixture.selection)
        try await system.handle(.authorizationChanged(.approved))
        let cycle = try await system.configure(policy: .standard, selection: fixture.selection)
        await platform.failNext(.monitoring)
        await #expect(throws: ScreenTimeServiceError.monitoringFailed) {
            try await platform.installMonitoring(for: cycle, selection: fixture.selection)
        }
        try await platform.installMonitoring(for: cycle, selection: fixture.selection)
        let stream = await platform.thresholdEvents()
        var events = stream.makeAsyncIterator()
        let event = UsageThresholdEvent(cycleID: cycle.id, reachedAt: fixture.date)
        try await platform.emitThreshold(event)
        #expect(await events.next() == event)
        try await platform.applyShield(for: fixture.selection, cycleID: cycle.id)
        #expect(await platform.reconcileShield() == .applied)
        await platform.stopMonitoring(cycleID: cycle.id)
        try await platform.removeShield(cycleID: cycle.id)
        #expect(await platform.reconcileShield() == .clear)
    }
}

struct TestFixture {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let date = Date(timeIntervalSince1970: 1_000)
    let selection = ActivitySelection(id: UUID(), applicationCount: 1, categoryCount: 0, webDomainCount: 0)
    var file: URL { directory.appendingPathComponent("state.json") }

    func system() throws -> EarnlySystem {
        try EarnlySystem(fileURL: file, provenance: .simulated, now: { [date] in date })
    }

    func remove() { try? FileManager.default.removeItem(at: directory) }

    func restrict(_ system: EarnlySystem) async throws -> UsageCycle {
        try await system.handle(.authorizationChanged(.approved))
        let policy = try ScreenTimePolicy(initialAllowance: .fifteen, requiredQuestions: 2, rewardedMinutes: 7)
        let cycle = try await system.configure(policy: policy, selection: selection)
        try await system.handle(.monitoringInstalled(cycleID: cycle.id))
        try await system.handle(.accessReleased(cycleID: cycle.id))
        try await system.handle(.thresholdReached(cycleID: cycle.id))
        try await system.handle(.shieldApplied(cycleID: cycle.id))
        return cycle
    }
}
