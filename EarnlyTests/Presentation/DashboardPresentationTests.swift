import XCTest
@testable import Earnly

@MainActor
final class DashboardPresentationTests: XCTestCase {
    private func snapshot(_ configure: (inout ServiceSnapshot) -> Void) -> ServiceSnapshot {
        var s = ServiceSnapshot.fresh(provenance: .simulated)
        s.authorization = .approved
        s.selection = ActivitySelectionSummary(id: UUID(), applications: 1, categories: 0, webDomains: 0)
        s.cycleID = UUID()
        configure(&s)
        return s
    }

    func testAuthorizationStatesRender() {
        var s = ServiceSnapshot.fresh(provenance: .simulated)
        XCTAssertEqual(DashboardPresentation.make(from: s).state, .authorizationRequired)
        for status in [AuthorizationStatus.denied, .revoked, .unavailable] {
            s.authorization = status
            let d = DashboardPresentation.make(from: s)
            XCTAssertEqual(d.state, .authorizationRecovery)
            XCTAssertEqual(d.primary?.action, .reviewAccess)
        }
    }

    func testEmptySelectionDoesNotClaimMonitoring() {
        var s = ServiceSnapshot.fresh(provenance: .simulated)
        s.authorization = .approved
        XCTAssertEqual(DashboardPresentation.make(from: s).state, .selectionRequired)
        XCTAssertEqual(MonitoringStatus.make(from: s).kind, .off)
    }

    func testUnsupportedRemainingUsageIsHonest() {
        let s = snapshot { $0.stage = .available }
        let d = DashboardPresentation.make(from: s)
        XCTAssertEqual(d.state, .allowanceActive)
        XCTAssertEqual(d.title, "10-minute allowance active")
        XCTAssertEqual(d.hero?.isMeasured, false)
        XCTAssertFalse(d.hero?.value.contains(":") ?? true)
        XCTAssertTrue(d.hero?.caption.contains("isn't measured") ?? false)
    }

    func testMeasuredRemainingShownOnlyWhenSupplied() {
        let s = snapshot { $0.stage = .available; $0.remainingMinutes = 7 }
        let d = DashboardPresentation.make(from: s)
        XCTAssertEqual(d.hero?.value, "7 min")
        XCTAssertEqual(d.hero?.isMeasured, true)
    }

    func testRestrictedMakesPracticeThePrimaryAction() {
        let d = DashboardPresentation.make(from: snapshot { $0.stage = .restricted })
        XCTAssertEqual(d.state, .restricted)
        XCTAssertEqual(d.primary?.action, .startPractice)
    }

    func testInterruptedPracticeOffersResume() {
        let d = DashboardPresentation.make(from: snapshot {
            $0.stage = .practiceInProgress
            $0.activeSession = DevelopmentScreenTimeService.session(answered: 4, complete: false)
        })
        XCTAssertEqual(d.state, .practiceInProgress)
        XCTAssertEqual(d.primary?.action, .resumePractice)
        XCTAssertEqual(d.hero?.value, "4 of 10")
    }

    func testRewardPendingNeverSaysUnlocked() {
        let session = DevelopmentScreenTimeService.session(answered: 10, complete: true)
        let pending = DashboardPresentation.make(from: snapshot {
            $0.stage = .rewardPending
            $0.activeSession = session
            $0.pendingReward = PendingReward(sessionID: session.id, minutes: 10, releaseFailed: false)
        })
        XCTAssertEqual(pending.state, .restoringAccess)
        XCTAssertEqual(pending.title, "Time earned. Restoring access.")
        XCTAssertNil(pending.primary)

        let failed = DashboardPresentation.make(from: snapshot {
            $0.stage = .failed(.shield)
            $0.activeSession = session
            $0.pendingReward = PendingReward(sessionID: session.id, minutes: 10, releaseFailed: true)
        })
        XCTAssertEqual(failed.state, .releaseFailed)
        XCTAssertEqual(failed.primary?.action, .retryRelease)
        XCTAssertFalse(failed.title.lowercased().contains("unlocked"))
    }

    func testReleasedRewardShowsSuccess() {
        let d = DashboardPresentation.make(from: snapshot { $0.stage = .available; $0.releasedRewardMinutes = 10 })
        XCTAssertEqual(d.state, .rewardEarned)
        XCTAssertEqual(d.tone, .success)
    }

    func testMonitoringFailureAndPending() {
        XCTAssertEqual(DashboardPresentation.make(from: snapshot { $0.stage = .failed(.monitoring) }).state, .monitoringFailed)
        XCTAssertEqual(DashboardPresentation.make(from: snapshot { $0.stage = .configuring }).state, .monitoringPending)
    }
}
