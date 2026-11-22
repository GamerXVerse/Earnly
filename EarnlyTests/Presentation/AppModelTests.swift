import XCTest
@testable import Earnly

@MainActor
final class AppModelTests: XCTestCase {
    private func make(_ fixture: DevelopmentFixture) -> (AppModel, DevelopmentScreenTimeService) {
        let service = DevelopmentScreenTimeService(fixture: fixture, latency: .zero)
        return (AppModel(service: service, defaults: nil), service)
    }

    func testOnboardingProgression() {
        let flow = OnboardingModel()
        XCTAssertTrue(flow.isFirst)
        for _ in 0..<(OnboardingModel.stepCount - 1) { flow.next() }
        XCTAssertTrue(flow.isLast)
        flow.next()
        XCTAssertEqual(flow.step, OnboardingModel.stepCount - 1)
        flow.back()
        XCTAssertEqual(flow.step, OnboardingModel.stepCount - 2)

        let (model, _) = make(.freshInstall)
        XCTAssertFalse(model.hasCompletedOnboarding)
        model.completeOnboarding()
        XCTAssertTrue(model.hasCompletedOnboarding)
    }

    func testAuthorizationOnlyShowsAuthorizedAfterServiceConfirms() async {
        let (model, service) = make(.freshInstall)
        await model.reconcile()
        XCTAssertEqual(model.authorization, .notRequested)
        service.nextAuthorizationResult = .approved
        await model.requestAuthorization()
        XCTAssertEqual(model.authorization, .authorized)
    }

    func testDeniedIsNotPromptedAgain() async {
        let (model, service) = make(.freshInstall)
        await model.reconcile()
        service.nextAuthorizationResult = .denied
        await model.requestAuthorization()
        XCTAssertEqual(model.authorization, .denied)
        service.nextAuthorizationResult = .approved
        await model.requestAuthorization()
        XCTAssertEqual(model.authorization, .denied, "A decided state must not prompt again")
    }

    func testSelectionCancellationChangesNothing() async {
        let (model, _) = make(.selectionEmpty)
        await model.reconcile()
        await model.handlePickerOutcome(.cancelled)
        XCTAssertEqual(model.selectionFlow, .cancelled)
        XCTAssertNil(model.snapshot?.selection)
        XCTAssertEqual(model.monitoringStatus.kind, .off)
    }

    func testEmptySelectionIsRejectedWithoutServiceCall() async {
        let (model, _) = make(.selectionEmpty)
        await model.reconcile()
        await model.handlePickerOutcome(.selected(ActivitySelectionSummary(id: UUID(), applications: 0, categories: 0, webDomains: 0)))
        XCTAssertEqual(model.selectionFlow, .empty)
        XCTAssertNil(model.snapshot?.selection)
    }

    func testSelectionTurnsMonitoringOnOnlyAfterConfirmation() async {
        let (model, _) = make(.selectionEmpty)
        await model.reconcile()
        await model.handlePickerOutcome(.selected(ActivitySelectionSummary(id: UUID(), applications: 2, categories: 0, webDomains: 0)))
        XCTAssertEqual(model.snapshot?.stage, .available)
        XCTAssertEqual(model.monitoringStatus.kind, .on)
    }

    func testMonitoringFailureIsSurfacedAndRetryable() async {
        let (model, service) = make(.selectionEmpty)
        service.failNextMonitoring = true
        await model.reconcile()
        await model.handlePickerOutcome(.selected(ActivitySelectionSummary(id: UUID(), applications: 1, categories: 0, webDomains: 0)))
        XCTAssertEqual(model.snapshot?.stage, .failed(.monitoring))
        XCTAssertEqual(model.monitoringStatus.kind, .failed)
        await model.retryPendingOperation()
        XCTAssertEqual(model.snapshot?.stage, .available)
    }

    func testAllowanceChangeApplies() async {
        let (model, _) = make(.allowanceActive)
        await model.reconcile()
        await model.setAllowance(minutes: 15)
        XCTAssertEqual(model.policy.allowanceMinutes, 15)
        XCTAssertEqual(model.snapshot?.stage, .available)
    }

    func testAllowanceChangeLockedDuringPracticeShowsError() async {
        let (model, _) = make(.interruptedPractice)
        await model.reconcile()
        await model.setAllowance(minutes: 15)
        XCTAssertEqual(model.change, .failed(.configurationLocked))
        XCTAssertEqual(model.policy.allowanceMinutes, 10)
    }

    func testRewardRetryNeverCreatesSecondCredit() async {
        let (model, service) = make(.releaseFailure)
        await model.reconcile()
        XCTAssertEqual(model.rewardOutcome, .releaseFailed(minutes: 10))
        let earnedBefore = model.snapshot?.earnedMinutes
        await model.retryPendingOperation()
        XCTAssertEqual(model.rewardOutcome, .released(minutes: 10))
        XCTAssertEqual(model.snapshot?.earnedMinutes, earnedBefore)
        XCTAssertEqual(service.rewardGrantCount, 0)
    }

    func testFullFlowReleaseFailureThenRetryGrantsOnce() async throws {
        let (model, service) = make(.thresholdReached)
        await model.reconcile()
        let flow = PracticeFlowModel(app: model)
        await flow.load()
        for _ in 0..<10 {
            flow.select(flow.current!.correctAnswerID)
            await flow.submit()
            service.failNextRelease = (flow.session?.isComplete == true)
            await flow.advance()
        }
        XCTAssertEqual(flow.phase, .completed)
        XCTAssertEqual(model.rewardOutcome, .releaseFailed(minutes: 10))
        XCTAssertEqual(service.rewardGrantCount, 1)
        await model.retryPendingOperation()
        await model.completeReward(sessionID: flow.session!.id)
        XCTAssertEqual(model.rewardOutcome, .released(minutes: 10))
        XCTAssertEqual(service.rewardGrantCount, 1)
        XCTAssertEqual(model.snapshot?.earnedMinutes, 10)
    }

    func testIncompleteRewardIsFinalizedOnReconcile() async throws {
        let (model, service) = make(.thresholdReached)
        let session = try await service.startPractice()
        for q in session.questions { _ = try await service.submitAnswer(sessionID: session.id, questionID: q.id, answerID: q.correctAnswerID) }
        await model.reconcile()   // simulates relaunch between last answer and grant
        XCTAssertEqual(service.rewardGrantCount, 1)
        XCTAssertEqual(model.rewardOutcome, .released(minutes: 10))
    }

    func testDisconnectedServiceNeverSimulatesSuccess() async throws {
        let service = DisconnectedScreenTimeService()
        let snapshot = try await service.snapshot()
        XCTAssertEqual(snapshot.authorization, .unavailable)
        XCTAssertFalse(service.isSimulated)
        do { _ = try await service.requestAuthorization(); XCTFail("must throw") }
        catch { XCTAssertEqual(error as? ServiceFailure, .notConnected) }
    }
}
