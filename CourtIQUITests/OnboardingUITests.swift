import XCTest

final class OnboardingUITests: XCTestCase {
    let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launchArguments = ["--uitesting", "--skip-auth"]
        app.launch()
    }

    func testOnboardingScreenLoads() {
        XCTAssertTrue(app.staticTexts["CourtIQ"].exists)
        XCTAssertTrue(app.buttons["Get Started"].exists)
    }

    func testGetStartedNavigatesToSignUp() {
        app.buttons["Get Started"].tap()
        XCTAssertTrue(app.navigationBars["Create Account"].waitForExistence(timeout: 2))
    }
}
