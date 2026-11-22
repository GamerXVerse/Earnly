import XCTest
@testable import Earnly

final class PreviewModelTests: XCTestCase {
    func testSessionFlowAndScoring() {
        let session = PreviewPracticeSession(startingAt: 0)
        XCTAssertEqual(session.progressText, "Question 1 of 10")
        session.select(session.current.correctIndex)
        session.submit()
        XCTAssertEqual(session.correctCount, 1)
        XCTAssertEqual(session.phase, .submitted)
        session.advance()
        XCTAssertEqual(session.index, 1)
        XCTAssertNil(session.selectedChoice)
    }

    func testSessionCompletes() {
        let session = PreviewPracticeSession(startingAt: 9)
        session.select(0)
        session.submit()
        session.advance()
        XCTAssertEqual(session.phase, .completed)
        XCTAssertEqual(session.progressFraction, 1)
    }

    func testSubmitRequiresSelection() {
        let session = PreviewPracticeSession()
        session.submit()
        XCTAssertEqual(session.phase, .answering)
    }

    func testSampleQuestionsAreWellFormed() {
        for q in PreviewQuestion.samples {
            XCTAssertTrue(q.choices.indices.contains(q.correctIndex))
            XCTAssertFalse(q.explanation.isEmpty)
        }
    }

    func testDashboardStatesAreDeterministic() {
        let profile = PreviewStudyProfile.sample
        XCTAssertEqual(PreviewRestrictionState.make(for: .available, profile: profile).remainingText, "08:42")
        XCTAssertEqual(PreviewRestrictionState.make(for: .exhausted, profile: profile).remainingText, "00:00")
        XCTAssertEqual(PreviewRestrictionState.make(for: .firstLaunchIncomplete, profile: profile).remainingText, "--:--")
        XCTAssertEqual(PreviewRestrictionState.make(for: .authorizationUnavailable, profile: profile).primaryAction, .reviewPermission)
        XCTAssertEqual(PreviewDashboardState.allCases.count, 7)
    }

    func testOnboardingCompletionDependsOnAuthorization() {
        let granted = PreviewAppModel()
        granted.requestAuthorization()
        granted.completeOnboarding()
        XCTAssertEqual(granted.dashboardState, .available)

        let skipped = PreviewAppModel()
        skipped.completeOnboarding()
        XCTAssertEqual(skipped.dashboardState, .authorizationUnavailable)
    }

    func testAPSubjectSelectionSelectsAP() {
        let profile = PreviewStudyProfile()
        profile.toggle(.biology)
        XCTAssertTrue(profile.selectedExams.contains(.ap))
        profile.toggle(.ap)
        XCTAssertTrue(profile.selectedAPSubjects.isEmpty)
    }
}
