import XCTest

/// Captures a guided tour of the app as named screenshot attachments for
/// the App Store preview. Attachments are exported from the .xcresult and
/// assembled into a ~20s motion video with ffmpeg (Ken Burns + crossfades).
///
/// Navigation is defensive: each step taps only if its control exists, so a
/// missing/renamed control degrades gracefully. A screenshot is taken at
/// every stop regardless, so the export always yields an ordered set.
final class CourtIQAppPreviewUITest: XCTestCase {

    let app = XCUIApplication()

    override func setUp() { continueAfterFailure = true }

    private func snap(_ name: String) {
        let shot = XCUIScreen.main.screenshot()
        let att = XCTAttachment(screenshot: shot)
        att.name = name
        att.lifetime = .keepAlways
        add(att)
    }

    @discardableResult
    private func tapIfExists(_ el: XCUIElement, _ timeout: TimeInterval = 4) -> Bool {
        if el.waitForExistence(timeout: timeout) && el.isHittable { el.tap(); return true }
        return false
    }

    func testAppPreviewTour() {
        app.launchArguments = ["-seedPreviewData"]
        app.launch()
        sleep(4)
        snap("01-today")

        // Court Tap Drill — signature daily game
        if tapIfExists(app.buttons["Start"]) {
            sleep(2)
            snap("02-drill")
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.30, dy: 0.42)).tap()
            sleep(2)
            snap("03-drill-reveal")
            _ = tapIfExists(app.buttons["Next"], 2)
            _ = tapIfExists(app.buttons["Done"], 2)
            _ = tapIfExists(app.navigationBars.buttons.element(boundBy: 0), 2)
        }

        let tabs = app.tabBars.firstMatch

        if tapIfExists(tabs.buttons["Practice"]) {
            sleep(2)
            snap("04-practice")
            if tapIfExists(app.buttons["Mobility"], 2) || tapIfExists(app.staticTexts["Mobility"], 2) {
                sleep(2)
                snap("05-mobility")
                _ = tapIfExists(app.navigationBars.buttons.element(boundBy: 0), 2)
            }
        }

        if tapIfExists(tabs.buttons["Matches"]) {
            sleep(2)
            // First Matches visit shows a "how match logging works" sheet —
            // dismiss it so the populated list + insights are visible.
            _ = tapIfExists(app.buttons["Done"], 2)
            sleep(1)
            snap("06-matches")
            if tapIfExists(app.buttons["View insights"], 3) {
                sleep(2)
                snap("06b-progress")
                _ = tapIfExists(app.navigationBars.buttons.element(boundBy: 0), 2)
            }
        }

        if tapIfExists(tabs.buttons["Training"]) {
            sleep(2)
            snap("07-training")
            if tapIfExists(app.buttons["Open 8-Week Plan"], 3) {
                sleep(2)
                snap("08-training-detail")
                _ = tapIfExists(app.navigationBars.buttons.element(boundBy: 0), 2)
            }
        }

        if tapIfExists(tabs.buttons["Profile"]) {
            sleep(1)
            snap("09-profile")
            app.swipeUp()
            sleep(1)
            if tapIfExists(app.buttons["AI Coach"], 2) || tapIfExists(app.staticTexts["AI Coach"], 2) {
                sleep(2)
                snap("10-aicoach")
            }
        }
    }
}
