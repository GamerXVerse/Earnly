import Foundation
import Testing
@testable import EarnlySystems

struct PersistenceTests {
    @Test func firstLaunchAndInterruptedSessionRestore() async throws {
        let fixture = TestFixture()
        defer { fixture.remove() }
        let system = try fixture.system()
        #expect(await system.dashboard().restriction == .unconfigured)
        let profile = StudyProfile(exams: [.sat], preferredDifficulty: .advanced)
        try await system.saveStudyProfile(profile)
        _ = try await fixture.restrict(system)
        let session = try await system.startPractice()
        let first = session.questions[0]
        let saved = try await system.submitAnswer(sessionID: session.id, questionID: first.id,
                                                  answerID: first.correctAnswerID)
        let reopened = try fixture.system()
        #expect(await reopened.studyProfile() == profile)
        #expect(await reopened.dashboard().restriction == .authorizationUnavailable(.unavailable))
        try await reopened.handle(.authorizationChanged(.approved))
        #expect(try await reopened.startPractice() == saved)

        let second = session.questions[1]
        _ = try await reopened.submitAnswer(sessionID: session.id, questionID: second.id,
                                            answerID: second.correctAnswerID)
        let credit = try await reopened.grantReward(for: session.id)
        let pendingOperation = await reopened.pendingOperation()
        let recovered = try fixture.system()
        #expect(await recovered.pendingOperation() == nil)
        try await recovered.handle(.authorizationChanged(.approved))
        #expect(await recovered.pendingOperation() == pendingOperation)
        #expect(try await recovered.grantReward(for: session.id) == credit)
        #expect(await recovered.rewardLedger().transactions.count == 1)
    }

    @Test func transientAuthorizationRefreshDefersCurrentThreshold() async throws {
        let fixture = TestFixture()
        defer { fixture.remove() }
        let system = try fixture.system()
        try await system.handle(.authorizationChanged(.approved))
        let cycle = try await system.configure(policy: .standard, selection: fixture.selection)
        try await system.handle(.monitoringInstalled(cycleID: cycle.id))
        try await system.handle(.accessReleased(cycleID: cycle.id))

        let reopened = try fixture.system()
        try await reopened.handle(.authorizationChanged(.unavailable))
        let receipt = UsageThresholdEvent(cycleID: cycle.id, reachedAt: fixture.date)
        await #expect(throws: LifecycleError.authorizationRequired(.unavailable)) {
            try await reopened.receiveThreshold(receipt)
        }
        try await reopened.handle(.authorizationChanged(.approved))
        try await reopened.receiveThreshold(receipt)
        #expect(await reopened.dashboard().restriction == .applyingShield)

        let restarted = try fixture.system()
        try await restarted.handle(.authorizationChanged(.denied))
        #expect(await restarted.dashboard().restriction == .authorizationUnavailable(.revoked))
        try await restarted.handle(.authorizationChanged(.approved))
        #expect(await restarted.dashboard().restriction == .selectionRequired)
    }

    @Test func corruptionDoesNotOverwriteStateAndValidBackupCanBeRestored() async throws {
        let fixture = TestFixture()
        defer { fixture.remove() }
        let system = try fixture.system()
        _ = try await fixture.restrict(system)
        let valid = try Data(contentsOf: fixture.file)

        let corrupt = Data("truncated".utf8)
        try corrupt.write(to: fixture.file, options: .atomic)
        #expect(throws: PersistenceError.corrupt) { try fixture.system() }
        #expect(try Data(contentsOf: fixture.file) == corrupt)

        let incompatible = Data(#"{"version":817}"#.utf8)
        try incompatible.write(to: fixture.file, options: .atomic)
        #expect(throws: PersistenceError.unsupportedVersion(817)) { try fixture.system() }
        #expect(try Data(contentsOf: fixture.file) == incompatible)

        try valid.write(to: fixture.file, options: .atomic)
        let recovered = try fixture.system()
        try await recovered.handle(.authorizationChanged(.approved))
        #expect(await recovered.dashboard().restriction == .restricted)
        #expect(await recovered.rewardLedger().transactions.isEmpty)
    }

    @Test func rejectsOrphanedRewardAndDoesNotRepairItByIssuingCredit() throws {
        let fixture = TestFixture()
        defer { fixture.remove() }
        var invalid = LocalState()
        let missingSession = UUID()
        invalid.ledger.transactions[missingSession] = RewardTransaction(
            sessionID: missingSession, earnedMinutes: 10, earnedAt: fixture.date
        )
        try LocalStateFile(url: fixture.file).save(invalid)
        #expect(throws: PersistenceError.invalidState) { try fixture.system() }
    }

    @Test func failedCommitDoesNotPublishNewState() async throws {
        let fixture = TestFixture()
        defer { fixture.remove() }
        let system = try fixture.system()
        // Occupy the destination with a directory after loading.
        try FileManager.default.createDirectory(at: fixture.file, withIntermediateDirectories: true)
        let update = StudyProfile(exams: [.act])
        await #expect(throws: PersistenceError.writeFailed) { try await system.saveStudyProfile(update) }
        #expect(await system.studyProfile() == StudyProfile())
    }
}
