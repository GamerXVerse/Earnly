import XCTest

final class EarnlyUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    private func launch(_ fixture: String? = nil, skipOnboarding: Bool = true) -> XCUIApplication {
        let app = XCUIApplication()
        var args = ["-earnly-no-latency", "-earnly-fresh-defaults"]
        if skipOnboarding { args.append("-earnly-skip-onboarding") }
        if let fixture { args += ["-earnly-fixture", fixture] }
        app.launchArguments = args
        app.launch()
        return app
    }

    func testOnboardingReachesToday() {
        let app = launch(skipOnboarding: false)
        app.buttons["Get started"].tap()
        app.buttons["Continue"].tap()
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "SAT")).firstMatch.tap()
        app.buttons["Continue"].tap()
        app.buttons["Continue"].tap()
        app.buttons["Allow Screen Time access"].tap()
        XCTAssertTrue(app.buttons["Continue"].waitForExistence(timeout: 3))
        app.buttons["Continue"].tap()
        app.buttons["Choose apps"].tap()
        app.buttons["Done"].tap()
        XCTAssertTrue(app.buttons["Start using Earnly"].waitForExistence(timeout: 3))
        app.buttons["Start using Earnly"].tap()
        XCTAssertTrue(app.staticTexts["10-minute allowance active"].waitForExistence(timeout: 3))
    }

    func testRestrictedStateOffersPractice() {
        let app = launch("thresholdReached")
        XCTAssertTrue(app.buttons["Start practice"].waitForExistence(timeout: 3))
    }

    func testPracticeAnswerFlow() {
        let app = launch("thresholdReached")
        app.buttons["Start practice"].tap()
        XCTAssertTrue(app.staticTexts["Question 1 of 10"].waitForExistence(timeout: 3))
        app.buttons["Choice C: 7"].tap()
        app.buttons["Check answer"].tap()
        XCTAssertTrue(app.staticTexts["Correct"].waitForExistence(timeout: 2))
    }

    func testInterruptedPracticeResumes() {
        let app = launch("interruptedPractice")
        XCTAssertTrue(app.staticTexts["Question 5 of 10"].waitForExistence(timeout: 3))
    }

    func testReleaseFailureOffersRetryWithoutRepeatingQuestions() {
        let app = launch("releaseFailure")
        XCTAssertTrue(app.staticTexts["Time earned. Access wasn't restored."].waitForExistence(timeout: 3))
        app.buttons["Try again"].tap()
        XCTAssertTrue(app.staticTexts["10 minutes earned"].waitForExistence(timeout: 3))
    }
}
