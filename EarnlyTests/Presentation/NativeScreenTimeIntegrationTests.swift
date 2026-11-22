import EarnlySystems
import XCTest
@testable import Earnly

@MainActor
final class NativeScreenTimeIntegrationTests: XCTestCase {
    func testFactoryRequiresExplicitDebugSimulation() {
        XCTAssertFalse(ScreenTimeServiceFactory.make(arguments: []).isSimulated)
        #if DEBUG
        XCTAssertTrue(ScreenTimeServiceFactory.make(arguments: ["-earnly-demo"]).isSimulated)
        #else
        XCTAssertFalse(ScreenTimeServiceFactory.make(arguments: ["-earnly-demo"]).isSimulated)
        #endif
    }

    func testAllowanceAppearsActiveOnlyForVerifiedRegistration() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let system = try EarnlySystem(fileURL: directory.appendingPathComponent("state.json"), provenance: .observed)
        try await system.handle(.authorizationChanged(.approved))
        let cycle = try await system.configure(
            policy: .standard, selection: ActivitySelection(id: UUID(), applicationCount: 1, categoryCount: 0, webDomainCount: 0)
        )
        XCTAssertEqual(NativeScreenTimeService.stage(.available(cycle), monitoring: .registered(cycle)), .available)
        XCTAssertEqual(NativeScreenTimeService.stage(.available(cycle), monitoring: .interrupted), .failed(.monitoringInterrupted))
        XCTAssertEqual(NativeScreenTimeService.stage(.available(cycle), monitoring: .cleanupPending), .failed(.cleanupPending))
    }

    func testFrontendExamChoicesMapToTheNativeCatalog() {
        let profile = PreviewStudyProfile(selectedExams: [.sat, .ap], selectedAPSubjects: [.calculusAB])
        XCTAssertEqual(NativeScreenTimeService.exams(from: profile), [.sat, .ap(subjectCode: "calculus-ab")])
        XCTAssertFalse(PreviewStudyProfile(selectedExams: [.ap]).hasConcreteExam)
        XCTAssertEqual(ServiceFailure.from(PracticeError.insufficientQuestions(required: 10, available: 2)),
                       .insufficientQuestions(required: 10, available: 2))
    }

    func testInterruptedMonitoringOffersSettingsEvenWithPendingReward() {
        var snapshot = ServiceSnapshot.fresh(provenance: .observed)
        snapshot.authorization = .approved
        snapshot.stage = .failed(.monitoringInterrupted)
        snapshot.pendingReward = PendingReward(sessionID: UUID(), minutes: 10, releaseFailed: false)
        let presentation = DashboardPresentation.make(from: snapshot)
        XCTAssertEqual(presentation.state, .monitoringFailed)
        XCTAssertEqual(presentation.primary?.action, .reviewMonitoring)
    }
}
