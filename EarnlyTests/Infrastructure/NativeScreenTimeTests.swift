import Foundation
import Testing
@testable import EarnlySystems

struct NativeScreenTimeTests {
    @Test func recoveryExcludesOnlyTheHostTokenOrTheAffectedAppSelection() throws {
        let selectionID = UUID()
        let apps: Set<Int> = [1, 2]
        let identified = HostShieldExclusion(selectionID: selectionID, opaqueToken: Data([1]))
        let unidentified = HostShieldExclusion(selectionID: selectionID, opaqueToken: nil)
        let decode: (Data) throws -> Int = { Int(try #require($0.first)) }

        #expect(try identified.applicationsToShield(apps, selectionID: selectionID, decode: decode) == [2])
        #expect(try unidentified.applicationsToShield(apps, selectionID: selectionID, decode: decode).isEmpty)
        #expect(try unidentified.applicationsToShield(apps, selectionID: UUID(), decode: decode) == apps)
    }

    @Test(arguments: [InitialAllowance.one, .five])
    func shortAllowancesRegisterAndRestrictAtTheSelectedThreshold(_ allowance: InitialAllowance) async throws {
        let fixture = NativeFixture()
        defer { fixture.remove() }
        let (system, coordinator) = try fixture.open()
        let policy = try ScreenTimePolicy(initialAllowance: allowance)
        try await coordinator.configure(policy: policy, selection: fixture.selection)
        let registration = try fixture.registration()

        #expect(registration.minutes == allowance.rawValue)
        #expect(registration.end.timeIntervalSince(registration.start) >= 15 * 60)
        #expect(registration.releaseConfirmed)
        #expect(fixture.backend.shieldStatus() == .clear)

        try fixture.threshold(registration)
        #expect(fixture.backend.shieldStatus() == .applied)
        try await coordinator.activate()
        #expect(await system.dashboard().mostRecentThresholdMinutes == .available(allowance.rawValue, provenance: .observed))
        let completed = try await fixture.complete(system)
        let credit = try await coordinator.finishPractice(sessionID: completed.id)
        #expect(credit.earnedMinutes == 10)
        #expect(try fixture.registration().minutes == 10)
        #expect(fixture.backend.shieldStatus() == .clear)
    }

    @Test func initialAllowancePreferenceCanBeSavedBeforeAuthorizationAndSelection() async throws {
        let fixture = NativeFixture()
        defer { fixture.remove() }
        let (system, coordinator) = try fixture.open()
        try await coordinator.setUnconfiguredAllowance(.fifteen)
        let dashboard = await system.dashboard()
        #expect(dashboard.authorization == .notDetermined)
        #expect(dashboard.policy.initialAllowance == .fifteen)
        #expect(dashboard.policy.requiredQuestions == 10)
        #expect(fixture.backend.registrationCount == 0)

        let (reopened, restarted) = try fixture.open()
        let saved = await reopened.dashboard().policy
        try await restarted.configure(policy: saved, selection: fixture.selection)
        #expect(try fixture.registration().minutes == 15)
        await #expect(throws: LifecycleError.configurationLocked) {
            try await restarted.setUnconfiguredAllowance(.ten)
        }
    }

    @Test func coldLaunchRefreshKeepsBackgroundShieldUntilPracticeIsCompleted() async throws {
        let fixture = NativeFixture()
        defer { fixture.remove() }
        let (_, original) = try fixture.open()
        try await fixture.configure(original)
        let first = try fixture.registration()
        try fixture.threshold(first)

        // Model a fresh AuthorizationCenter before the OS refresh completes.
        await fixture.authorization.setAuthorization(.notDetermined)
        await fixture.authorization.failNext(.authorization)
        let (reopened, restarted) = try fixture.open()
        try await restarted.activate()
        #expect(await reopened.dashboard().authorization == .unavailable)
        #expect(try fixture.registration().threshold != nil)
        #expect(fixture.backend.shieldStatus() == .applied)

        // A new launch with successful authorization reuses the original receipt.
        let (recovered, relaunched) = try fixture.open()
        try await relaunched.activate()
        try await relaunched.activate()
        #expect(try fixture.registration().cycleID == first.cycleID)
        #expect(await relaunched.dashboard().monitoring == .shielded)
        #expect(await recovered.dashboard().restriction == .restricted)
        #expect(await recovered.rewardLedger().transactions.isEmpty)

        let completed = try await fixture.complete(recovered)
        _ = try await relaunched.finishPractice(sessionID: completed.id)
        #expect(try fixture.registration().cycleID != first.cycleID)
        #expect(fixture.backend.shieldStatus() == .clear)
        #expect(await recovered.rewardLedger().transactions.count == 1)
    }

    @Test func changingSettingsCannotDiscardAnUnreconciledThreshold() async throws {
        let fixture = NativeFixture()
        defer { fixture.remove() }
        let (_, coordinator) = try fixture.open()
        try await fixture.configure(coordinator)
        let first = try fixture.registration()
        try fixture.threshold(first)

        await #expect(throws: LifecycleError.configurationLocked) {
            try await coordinator.configure(policy: .standard, selection: fixture.selection)
        }
        #expect(try fixture.registration().cycleID == first.cycleID)
        #expect(fixture.backend.shieldStatus() == .applied)
        try await coordinator.activate()
        #expect(await coordinator.dashboard().monitoring == .shielded)
    }

    @Test(arguments: [InitialAllowance.one, .five, .ten, .fifteen])
    func warnsOnceForTheCurrentReleasedGeneration(_ allowance: InitialAllowance) async throws {
        let fixture = NativeFixture()
        defer { fixture.remove() }
        let (_, coordinator) = try fixture.open()
        try await coordinator.configure(policy: .init(initialAllowance: allowance), selection: fixture.selection)
        let first = try fixture.registration()
        let leads: [InitialAllowance: Int] = [.one: 5, .five: 60, .ten: 120, .fifteen: 180]
        #expect(try fixture.platform.claimWarning(activity: first.name, event: "unrelated") == nil)
        #expect(try fixture.platform.claimWarning(activity: "stale", event: first.eventName) == nil)
        #expect(try fixture.platform.claimWarning(activity: first.name, event: first.eventName) == leads[allowance])
        #expect(try fixture.platform.claimWarning(activity: first.name, event: first.eventName) == nil)
        try fixture.threshold(first)
        #expect(try fixture.platform.claimWarning(activity: first.name, event: first.eventName) == nil)
        #expect(fixture.backend.shieldStatus() == .applied)
    }

    @Test(arguments: [1, 10])
    func reopensAndRepeatsEarnedAllowanceWithFreshUsage(_ minutesAndQuestions: Int) async throws {
        let fixture = NativeFixture()
        defer { fixture.remove() }
        let (system, coordinator) = try fixture.open()
        let policy = try ScreenTimePolicy(initialAllowance: .one, requiredQuestions: minutesAndQuestions,
                                          rewardedMinutes: minutesAndQuestions)
        try await coordinator.configure(policy: policy, selection: fixture.selection)
        let first = try fixture.registration()
        let firstCycle = try #require(await system.currentCycle())

        // Deliver usage only while the selected app is reported as foreground.
        #expect(try fixture.useSelectedApp(first, seconds: 30) == false)
        fixture.clock.advance(seconds: 600)
        #expect(fixture.backend.shieldStatus() == .clear)
        #expect(try fixture.useSelectedApp(first, seconds: 30))
        try await coordinator.activate()
        var current = first

        for rewardCount in 1...2 {
            let session = try await fixture.complete(system)
            #expect(session.attempts.count == minutesAndQuestions)
            let credit = try await coordinator.finishPractice(sessionID: session.id)
            #expect(credit.earnedMinutes == minutesAndQuestions)
            #expect(credit.activatedAt != nil)

            let next = try fixture.registration()
            #expect(next.cycleID != current.cycleID)
            #expect(next.minutes == minutesAndQuestions)
            #expect(fixture.backend.registrationCount == 1)
            #expect(try fixture.threshold(current) == false)
            let (reopened, relaunched) = try fixture.open()
            try await relaunched.activate()
            let activeCycle = try #require(await reopened.currentCycle())
            #expect(activeCycle.id != firstCycle.id)
            #expect(await relaunched.dashboard().monitoring == .registered(activeCycle))

            let seconds = minutesAndQuestions * 60
            #expect(try fixture.useSelectedApp(next, seconds: seconds / 2) == false)
            fixture.clock.advance(seconds: 900)
            #expect(fixture.backend.shieldStatus() == .clear)
            #expect(try fixture.useSelectedApp(next, seconds: seconds / 2))
            // The extension re-applies the shield before the host reconciles the receipt.
            #expect(fixture.backend.shieldStatus() == .applied)
            try await coordinator.activate()
            #expect(await coordinator.dashboard().monitoring == .shielded)
            #expect(await system.rewardLedger().transactions.count == rewardCount)
            #expect(try await coordinator.finishPractice(sessionID: session.id).consumedAtLeastMinutes == minutesAndQuestions)
            current = next
        }
    }

    @Test func losingRegistrationDuringShieldReleaseKeepsCreditUnactivated() async throws {
        let fixture = NativeFixture()
        defer { fixture.remove() }
        let (system, coordinator) = try fixture.open()
        try await fixture.configure(coordinator)
        try fixture.threshold(fixture.registration())
        try await coordinator.activate()
        let session = try await fixture.complete(system)

        fixture.backend.fail(.loseRegistrationOnClear)
        await #expect(throws: ScreenTimeServiceError.monitoringInterrupted) {
            try await coordinator.finishPractice(sessionID: session.id)
        }
        #expect(fixture.backend.shieldStatus() == .applied)
        #expect(await coordinator.dashboard().monitoring == .interrupted)
        #expect(await system.rewardLedger().transactions[session.id]?.activatedAt == nil)

        let (reopened, relaunched) = try fixture.open()
        try await relaunched.activate()
        #expect(fixture.backend.registrationCount == 0)
        #expect(fixture.backend.shieldStatus() == .applied)
        #expect(await reopened.rewardLedger().transactions.count == 1)
        #expect(await reopened.rewardLedger().transactions[session.id]?.activatedAt == nil)
    }

    @Test func registerAndReleaseFailuresKeepTheSameRewardAcrossRelaunch() async throws {
        let fixture = NativeFixture()
        defer { fixture.remove() }
        let (system, coordinator) = try fixture.open()
        try await fixture.configure(coordinator)
        try fixture.threshold(fixture.registration())
        try await coordinator.activate()
        let session = try await fixture.complete(system)
        fixture.backend.fail(.install)
        await #expect(throws: ScreenTimeServiceError.monitoringFailed) {
            try await coordinator.finishPractice(sessionID: session.id)
        }
        let generation = try fixture.registration().cycleID
        #expect(await system.rewardLedger().transactions[session.id]?.activatedAt == nil)
        #expect(fixture.backend.shieldStatus() == .applied)

        let (restored, restarted) = try fixture.open()
        try await restarted.activate()
        fixture.backend.fail(.clear)
        await #expect(throws: ScreenTimeServiceError.shieldingFailed) { try await restarted.retry() }
        let nativeDashboard = await restarted.dashboard()
        #expect(nativeDashboard.rewardReleasePending)
        #expect(nativeDashboard.dashboard.restriction == .failed(.shield))
        let installCount = fixture.backend.installCount
        #expect(try fixture.registration().cycleID == generation)
        #expect(await restored.rewardLedger().transactions[session.id]?.activatedAt == nil)

        let (recovered, resumed) = try fixture.open()
        try await resumed.activate()
        try await resumed.retry()
        #expect(fixture.backend.installCount == installCount)
        #expect(await recovered.rewardLedger().transactions.count == 1)
        #expect(await recovered.rewardLedger().transactions[session.id]?.activatedAt != nil)
    }

    @Test func callbackBetweenReleaseEffectAndHostCommitIsRecoveredWithoutClearingShield() async throws {
        let fixture = NativeFixture()
        defer { fixture.remove() }
        let (system, coordinator) = try fixture.open()
        try await fixture.configure(coordinator)
        try fixture.threshold(fixture.registration())
        try await coordinator.activate()
        let session = try await fixture.complete(system)
        _ = try await system.grantReward(for: session.id)
        let cycle = try #require(await system.currentCycle())
        try fixture.platform.install(cycle: cycle, selection: fixture.selection.summary)
        try await system.handle(.monitoringInstalled(cycleID: cycle.id))
        try fixture.platform.release(cycleID: cycle.id)
        try fixture.threshold(fixture.registration())

        let (restored, restarted) = try fixture.open()
        try await restarted.activate()
        let credit = try #require(await restored.rewardLedger().transactions[session.id])
        #expect(credit.consumedAtLeastMinutes == 10)
        #expect(fixture.backend.shieldStatus() == .applied)
        #expect(await restarted.dashboard().monitoring == .shielded)
    }

    @Test func callbackBeforeConfirmedReleaseDoesNotMarkRewardActivated() async throws {
        let fixture = NativeFixture()
        defer { fixture.remove() }
        let (system, coordinator) = try fixture.open()
        try await fixture.configure(coordinator)
        try fixture.threshold(fixture.registration())
        try await coordinator.activate()
        let session = try await fixture.complete(system)
        fixture.backend.fail(.clear)
        await #expect(throws: ScreenTimeServiceError.shieldingFailed) {
            try await coordinator.finishPractice(sessionID: session.id)
        }
        let registration = try fixture.registration()
        #expect(registration.releaseRequested && !registration.releaseConfirmed)
        try fixture.threshold(registration)

        let (restored, restarted) = try fixture.open()
        try await restarted.activate()
        #expect(await restored.dashboard().restriction == .failed(.monitoringInterrupted))
        #expect(await restored.rewardLedger().transactions[session.id]?.activatedAt == nil)
        #expect(fixture.backend.shieldStatus() == .applied)
    }

    @Test func foregroundRecoveryCreditsCompletionAfterLastAnswer() async throws {
        let fixture = NativeFixture()
        defer { fixture.remove() }
        let (system, coordinator) = try fixture.open()
        try await fixture.configure(coordinator)
        try fixture.threshold(fixture.registration())
        try await coordinator.activate()
        let session = try await fixture.complete(system)
        #expect(await system.rewardLedger().transactions.isEmpty)

        let (restored, restarted) = try fixture.open()
        try await restarted.activate()
        #expect(await restored.rewardLedger().transactions[session.id]?.activatedAt != nil)
        #expect(await restored.rewardLedger().transactions.count == 1)
    }

    @Test func earlyCallbackFencesReleaseAndRequiresFreshGeneration() async throws {
        let fixture = NativeFixture()
        defer { fixture.remove() }
        let (system, coordinator) = try fixture.open()
        try await fixture.platform.prepareSelectionForTest(fixture, system: system)
        let cycle = try #require(await system.currentCycle())
        try fixture.platform.install(cycle: cycle, selection: fixture.selection.summary)
        try fixture.threshold(fixture.registration())
        try await coordinator.activate()
        #expect(await system.dashboard().restriction == .failed(.thresholdBeforeRelease))
        #expect(fixture.backend.shieldStatus() == .applied)
        try await coordinator.retry()
        #expect(try fixture.registration().cycleID != cycle.id)
        #expect(fixture.backend.shieldStatus() == .clear)
    }

    @Test func intervalEndAndMissingRegistrationDoNotRearmOrEarnCredit() async throws {
        for lostRegistration in [false, true] {
            let fixture = NativeFixture()
            defer { fixture.remove() }
            let (system, coordinator) = try fixture.open()
            try await fixture.configure(coordinator)
            let first = try fixture.registration()
            if lostRegistration {
                try fixture.backend.stop(name: first.name)
            } else {
                fixture.clock.advance(seconds: 24 * 60 * 60)
                try fixture.platform.expire(activity: first.name)
            }
            try await coordinator.activate()
            #expect(await system.dashboard().restriction == .failed(.monitoringInterrupted))
            #expect(fixture.backend.shieldStatus() == .applied)
            #expect(await system.rewardLedger().transactions.isEmpty)
            await #expect(throws: LifecycleError.configurationLocked) { try await coordinator.retry() }
            #expect(try fixture.registration().cycleID == first.cycleID)
            try await coordinator.disable()
            #expect(fixture.backend.shieldStatus() == .clear)
        }
    }

    @Test func disableFencesCallbacksEvenWithPartialFailureAndRetainsEarnedReward() async throws {
        let fixture = NativeFixture()
        defer { fixture.remove() }
        let (system, coordinator) = try fixture.open()
        try await fixture.configure(coordinator)
        let initial = try fixture.registration()
        try fixture.threshold(initial)
        try await coordinator.activate()
        let session = try await fixture.complete(system)
        let credit = try await system.grantReward(for: session.id)

        fixture.backend.fail(.stop)
        await #expect(throws: ScreenTimeServiceError.monitoringFailed) { try await coordinator.disable() }
        #expect(await coordinator.dashboard().monitoring == .cleanupPending)
        #expect(fixture.backend.shieldStatus() == .clear)
        try fixture.threshold(initial)
        #expect(fixture.backend.shieldStatus() == .clear)
        fixture.backend.fail(.clear)
        await #expect(throws: ScreenTimeServiceError.shieldingFailed) { try await coordinator.disable() }

        let (restored, restarted) = try fixture.open()
        try await restarted.activate()
        #expect(await restored.dashboard().policy.isEnabled == false)
        #expect(try await restored.grantReward(for: session.id) == credit)
        try await fixture.configure(restarted)
        #expect(try await restored.grantReward(for: session.id).activatedAt != nil)
        #expect(await restored.rewardLedger().transactions.count == 1)
    }

    @Test func revocationWipesOpaqueSelectionAndRequiresRepick() async throws {
        let fixture = NativeFixture()
        defer { fixture.remove() }
        let (system, coordinator) = try fixture.open()
        try await fixture.configure(coordinator)
        try fixture.threshold(fixture.registration())
        try await coordinator.activate()
        let session = try await system.startPractice()
        await fixture.authorization.setAuthorization(.denied)
        try await coordinator.activate()
        #expect(await system.dashboard().authorization == .revoked)
        #expect(try fixture.platform.journal.read().selection == nil)
        #expect(fixture.backend.registrationCount == 0)
        #expect(fixture.backend.shieldStatus() == .clear)

        await fixture.authorization.setAuthorization(.approved)
        try await coordinator.activate()
        #expect(await system.dashboard().restriction == .selectionRequired)
        try await fixture.configure(coordinator)
        #expect(try await system.startPractice().id == session.id)
    }

    @Test func corruptAndIncompatibleJournalBytesSurviveCleanup() async throws {
        let fixture = NativeFixture()
        defer { fixture.remove() }
        let (system, coordinator) = try fixture.open()
        try await fixture.configure(coordinator)
        let first = try fixture.registration()
        try fixture.threshold(first)
        let file = fixture.platform.journal.directory.appendingPathComponent("screen-time.json")
        let bytes = Data(#"{"version":97}"#.utf8)
        try bytes.write(to: file, options: .atomic)
        #expect(throws: ScreenTimePersistenceError.unsupportedVersion(97)) { try fixture.threshold(first) }
        await #expect(throws: ScreenTimePersistenceError.unsupportedVersion(97)) { try await coordinator.disable() }
        #expect(fixture.backend.shieldStatus() == .clear)
        #expect(fixture.backend.registrationCount == 0)
        #expect(try Data(contentsOf: file) == bytes)
        #expect(await system.dashboard().policy.isEnabled == false)
        try Data("broken".utf8).write(to: file, options: .atomic)
        #expect(throws: ScreenTimePersistenceError.corrupt) { try fixture.platform.journal.read() }
    }

    @Test func concurrentJournalWritersObserveTheLatestCommittedState() async throws {
        let fixture = NativeFixture()
        defer { fixture.remove() }
        let (_, coordinator) = try fixture.open()
        try await fixture.configure(coordinator)
        let original = try fixture.registration()
        let path = fixture.platform.journal.directory
        try await withThrowingTaskGroup(of: Void.self) { group in
            for _ in 0..<16 {
                group.addTask {
                    try ScreenTimeJournal(directory: path).update { record in
                        var active = try #require(record.registration)
                        active.releaseConfirmed.toggle()
                        record.registration = active
                    }
                }
            }
            try await group.waitForAll()
        }
        #expect(try fixture.registration() == original)
    }

    @Test func emptySelectionCannotBeCommittedOrRegistered() async throws {
        let fixture = NativeFixture()
        defer { fixture.remove() }
        let (_, coordinator) = try fixture.open()
        let empty = StoredActivitySelection(
            summary: ActivitySelection(id: UUID(), applicationCount: 0, categoryCount: 0, webDomainCount: 0),
            opaqueSelection: Data([1])
        )
        await #expect(throws: ScreenTimePersistenceError.corrupt) {
            try await coordinator.configure(policy: .standard, selection: empty)
        }
        #expect(fixture.backend.registrationCount == 0)
        #expect(try fixture.platform.journal.read().selection == nil)
    }
}

private struct NativeFixture {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let backend = FakeScreenTimeBackend()
    let clock = NativeTestClock()
    let authorization = SimulatedScreenTime(authorization: .approved)
    let selection = StoredActivitySelection(
        summary: ActivitySelection(id: UUID(), applicationCount: 1, categoryCount: 0, webDomainCount: 0),
        opaqueSelection: Data([1])
    )

    var platform: GenerationScreenTime {
        GenerationScreenTime(journal: ScreenTimeJournal(directory: directory.appendingPathComponent("shared")),
                             backend: backend, now: { [clock] in clock.date })
    }

    func open() throws -> (EarnlySystem, ScreenTimeCoordinator) {
        let system = try EarnlySystem(fileURL: directory.appendingPathComponent("private/state.json"),
                                     provenance: .observed, now: { [clock] in clock.date })
        let coordinator = ScreenTimeCoordinator(system: system, authorization: authorization, platform: platform)
        return (system, coordinator)
    }

    func configure(_ coordinator: ScreenTimeCoordinator) async throws {
        try await coordinator.configure(policy: .standard, selection: selection)
    }

    func registration() throws -> MonitoringRegistration {
        try #require(platform.journal.read().registration)
    }

    @discardableResult
    func threshold(_ registration: MonitoringRegistration) throws -> Bool {
        try platform.threshold(activity: registration.name, event: registration.eventName, reachedAt: clock.date)
    }

    func useSelectedApp(_ registration: MonitoringRegistration, seconds: Int) throws -> Bool {
        clock.advance(seconds: TimeInterval(seconds))
        guard backend.crossedThreshold(registration, using: seconds) else { return false }
        return try threshold(registration)
    }

    func complete(_ system: EarnlySystem) async throws -> PracticeSession {
        var session = try await system.startPractice()
        for question in session.questions {
            session = try await system.submitAnswer(sessionID: session.id, questionID: question.id,
                                                   answerID: question.correctAnswerID)
        }
        return session
    }

    func remove() { try? FileManager.default.removeItem(at: directory) }
}

private extension GenerationScreenTime {
    func prepareSelectionForTest(_ fixture: NativeFixture, system: EarnlySystem) async throws {
        try await system.handle(.authorizationChanged(.approved))
        try prepareSelection(fixture.selection)
        try await system.configure(policy: .standard, selection: fixture.selection.summary)
    }
}

// All mutable test-double state is accessed under the lock.
private final class NativeTestClock: @unchecked Sendable {
    private let lock = NSLock()
    private var value = Date(timeIntervalSince1970: 1_760_000_000)
    var date: Date { lock.withLock { value } }
    func advance(seconds: TimeInterval) { lock.withLock { value.addTimeInterval(seconds) } }
}

private final class FakeScreenTimeBackend: ScreenTimeBackend, @unchecked Sendable {
    enum Failure: Hashable { case install, stop, clear, loseRegistrationOnClear }
    private let lock = NSLock()
    private var registrations: [String: MonitoringRegistration] = [:]
    private var failed: Set<Failure> = []
    private var installs = 0
    private var usageSeconds: [UUID: Int] = [:]
    private var shield: ShieldStatus = .clear

    var registrationCount: Int { lock.withLock { registrations.count } }
    var installCount: Int { lock.withLock { installs } }

    func fail(_ failure: Failure) { lock.withLock { _ = failed.insert(failure) } }

    func install(_ registration: MonitoringRegistration, selection: StoredActivitySelection) throws {
        try lock.withLock {
            if failed.remove(.install) != nil { throw ScreenTimeServiceError.monitoringFailed }
            registrations[registration.name] = registration
            usageSeconds[registration.cycleID] = 0
            installs += 1
        }
    }

    func contains(_ registration: MonitoringRegistration, selection: StoredActivitySelection) -> Bool {
        lock.withLock { registrations[registration.name]?.cycleID == registration.cycleID }
    }

    func crossedThreshold(_ registration: MonitoringRegistration, using seconds: Int) -> Bool {
        lock.withLock {
            guard registrations[registration.name] != nil else { return false }
            let previous = usageSeconds[registration.cycleID, default: 0]
            let updated = previous + seconds
            usageSeconds[registration.cycleID] = updated
            let threshold = registration.minutes * 60
            return previous < threshold && updated >= threshold
        }
    }

    func stop(name: String) throws {
        try lock.withLock {
            if failed.remove(.stop) != nil { throw ScreenTimeServiceError.monitoringFailed }
            registrations[name] = nil
        }
    }

    func stopOthers(keeping name: String?) throws {
        try lock.withLock {
            if failed.remove(.stop) != nil { throw ScreenTimeServiceError.monitoringFailed }
            registrations = registrations.filter { $0.key == name }
        }
    }

    func apply(_ selection: StoredActivitySelection, excludingHost: HostShieldExclusion?) { lock.withLock { shield = .applied } }

    func clear() throws {
        try lock.withLock {
            if failed.remove(.clear) != nil { throw ScreenTimeServiceError.shieldingFailed }
            shield = .clear
            if failed.remove(.loseRegistrationOnClear) != nil { registrations.removeAll() }
        }
    }

    func shieldStatus() -> ShieldStatus { lock.withLock { shield } }
}
