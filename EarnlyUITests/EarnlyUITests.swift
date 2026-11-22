import XCTest

final class EarnlyUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    func testOnboardingReachesToday() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Get started"].tap()
        app.buttons["Continue"].tap()
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "SAT")).firstMatch.tap()
        app.buttons["Continue"].tap()
        app.buttons["Continue"].tap()
        app.buttons["Allow Screen Time access"].tap()
        XCTAssertTrue(app.buttons["Start using Earnly"].waitForExistence(timeout: 2))
        app.buttons["Start using Earnly"].tap()
        XCTAssertTrue(app.buttons["Earn more time"].waitForExistence(timeout: 3))
    }

    func testPracticeAnswerFlow() {
        let app = XCUIApplication()
        app.launchArguments = ["-earnly-skip-onboarding"]
        app.launch()
        app.buttons["Earn more time"].tap()
        XCTAssertTrue(app.staticTexts["Question 1 of 10"].waitForExistence(timeout: 3))
        app.buttons["Choice C: 7"].tap()
        app.buttons["Check answer"].tap()
        XCTAssertTrue(app.staticTexts["Correct"].exists)
    }
}
