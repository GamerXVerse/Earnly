import XCTest
@testable import Earnly

@MainActor
final class NavigationAndPracticeTests: XCTestCase {
    private func snapshot(_ fixture: DevelopmentFixture) async -> ServiceSnapshot {
        try! await DevelopmentScreenTimeService(fixture: fixture, latency: .zero).snapshot()
    }

    func testRepeatedActivationPresentsUnfinishedSessionOnce() async {
        let router = AppRouter()
        let s = await snapshot(.interruptedPractice)
        router.routeOnActivation(s)
        XCTAssertNotNil(router.practiceLaunch)
        router.dismissPractice()
        router.routeOnActivation(s)
        router.routeOnActivation(s)
        XCTAssertNil(router.practiceLaunch, "Backgrounding and returning must not re-present the same session")
        XCTAssertEqual(router.presentationCount, 1)
    }

    func testStartPracticeDoesNotStackCovers() {
        let router = AppRouter()
        router.startPractice()
        router.startPractice()
        XCTAssertEqual(router.presentationCount, 1)
    }

    func testRestrictedWithoutSessionLandsOnTodayWithoutForcingPractice() async {
        let router = AppRouter()
        router.select(.progress)
        let s = await snapshot(.thresholdReached)
        router.routeOnActivation(s)
        XCTAssertEqual(router.selectedTab, .today)
        XCTAssertNil(router.practiceLaunch)
        router.select(.settings)
        router.routeOnActivation(s)
        XCTAssertEqual(router.selectedTab, .settings, "A second activation must not yank the user off their tab")
    }

    func testNoRoutingWithoutAuthorization() async {
        let router = AppRouter()
        router.routeOnActivation(await snapshot(.authorizationRevoked))
        XCTAssertNil(router.practiceLaunch)
        XCTAssertNil(router.lastRoutedEpisode)
    }

    func testInterruptedSessionResumesAtSavedQuestion() async {
        let service = DevelopmentScreenTimeService(fixture: .interruptedPractice, latency: .zero)
        let model = AppModel(service: service, defaults: nil)
        await model.reconcile()
        let flow = PracticeFlowModel(app: model)
        await flow.load()
        XCTAssertEqual(flow.phase, .answering)
        XCTAssertEqual(flow.progressText, "Question 5 of 10")
        XCTAssertEqual(flow.session?.answeredCount, 4)
    }

    func testDuplicateSubmissionIsBlockedInUI() async {
        let service = DevelopmentScreenTimeService(fixture: .interruptedPractice, latency: .milliseconds(60))
        let model = AppModel(service: service, defaults: nil)
        let flow = PracticeFlowModel(app: model)
        await flow.load()
        flow.select(flow.current!.correctAnswerID)
        async let first: Void = flow.submit()
        async let second: Void = flow.submit()
        _ = await (first, second)
        XCTAssertEqual(flow.session?.answeredCount, 5)
    }

    func testCompletionComesFromServiceNotCounting() async {
        let service = DevelopmentScreenTimeService(fixture: .interruptedPractice, latency: .zero)
        let model = AppModel(service: service, defaults: nil)
        let flow = PracticeFlowModel(app: model)
        await flow.load()
        for _ in 0..<6 {
            XCTAssertNotEqual(flow.phase, .completed)
            flow.select(flow.current!.correctAnswerID)
            await flow.submit()
            await flow.advance()
        }
        XCTAssertEqual(flow.phase, .completed)
        XCTAssertEqual(flow.session?.isComplete, true)
    }
}
