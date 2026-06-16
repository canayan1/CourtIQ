import XCTest

/// App Store marketing screenshot capture for the current IA
/// (Home / Train / Matches / Doubles / Coach). Each screen is saved as a named
/// `XCTAttachment` with `.keepAlways` so it survives into the `.xcresult` for
/// export to PNG. Navigation is defensive — every tap is guarded by an
/// existence/hittability check, and an optional screen that isn't reachable is
/// skipped rather than failing the whole run.
///
/// Launches with `-seedPreviewData`, which (see `CourtIQApp.seedPreviewData()`):
///   • completes onboarding + the health gate and grants premium, so the app
///     lands directly on the main tabs (past the hard paywall);
///   • seeds 7 matches (the most recent carries a full AI report), quiz history,
///     a Tennis Profile, a scored swing (82) and a doubles partner + score (87).
final class AppStoreScreenshotUITest: XCTestCase {

    let app = XCUIApplication()

    override func setUp() {
        continueAfterFailure = true
    }

    private func snap(_ name: String) {
        let shot = XCUIScreen.main.screenshot()
        let att = XCTAttachment(screenshot: shot)
        att.name = name
        att.lifetime = .keepAlways
        add(att)
    }

    @discardableResult
    private func tapIfExists(_ el: XCUIElement, _ timeout: TimeInterval = 4) -> Bool {
        if el.waitForExistence(timeout: timeout) && el.isHittable {
            el.tap()
            return true
        }
        return false
    }

    func testCaptureMarketingScreens() {
        app.launchArguments = ["-seedPreviewData"]
        app.launch()

        // Let the app settle on the main tabs (seed runs async on launch).
        sleep(5)

        let tabs = app.tabBars.firstMatch
        _ = tabs.waitForExistence(timeout: 15)

        // 1. Home — action-first landing (swing hero ring + 2×2 grid).
        _ = tapIfExists(tabs.buttons["Home"], 5)
        sleep(2)
        snap("home")

        // 2. Train tab.
        if tapIfExists(tabs.buttons["Train"], 5) {
            sleep(2)
            snap("train")
        }

        // 3. Matches tab — dismiss the first-visit tutorial sheet, then capture
        // the populated list, then drill into the most recent match (carries an
        // AI report) for the report detail screenshot.
        if tapIfExists(tabs.buttons["Matches"], 5) {
            sleep(2)
            _ = tapIfExists(app.buttons["Done"], 3)   // tutorial sheet
            sleep(1)
            snap("matches")

            // The match list sits below the streak header, mental-check card,
            // "View insights" hero and the calendar grid — scroll up to reveal
            // the most recent match row (it carries the seeded AI report), then
            // tap it. The detail opens the journal which renders the report.
            app.swipeUp()
            sleep(1)
            app.swipeUp()
            sleep(1)
            // Tap the most-recent opponent ("Riley", the latest seeded match).
            if tapIfExists(app.buttons["Riley"], 3)
                || tapIfExists(app.staticTexts["Riley"], 2) {
                sleep(2)
                // The journal editor renders the seeded "AI match analysis"
                // report card at the very top, so capture as-is.
                snap("match_report")
                _ = tapIfExists(app.navigationBars.buttons.element(boundBy: 0), 3)
                sleep(1)
            }
        }

        // 4. Doubles tab — shows the invite hero + a seeded partner card with a
        // compatibility score badge.
        if tapIfExists(tabs.buttons["Doubles"], 5) {
            sleep(2)
            snap("doubles")
        }

        // 5. Coach tab — the AI Coach.
        if tapIfExists(tabs.buttons["Coach"], 5) {
            sleep(3)
            snap("coach")
        }
    }

    /// Swing analysis RESULT screen. `-previewSwing` lands onboarded + premium
    /// (no paywall) on the main tabs, and makes SwingAnalysisView START in the
    /// result state with a sample forehand analysis + a 0–100 score. We open it
    /// from the Home swing hero — no video/network is needed for the capture.
    func testCaptureSwingResult() {
        app.launchArguments = ["-previewSwing"]
        app.launch()
        sleep(5)

        let tabs = app.tabBars.firstMatch
        _ = tabs.waitForExistence(timeout: 15)
        _ = tapIfExists(tabs.buttons["Home"], 5)
        sleep(1)

        // The Home swing hero is a NavigationLink labelled "Analyze your swing".
        // Tapping it opens SwingAnalysisView, which (under -previewSwing) is
        // already in the result state showing the sample analysis + score.
        if tapIfExists(app.buttons["Analyze your swing"], 5)
            || tapIfExists(app.staticTexts["Analyze your swing"], 3) {
            sleep(3)
            snap("swing")
        }
    }
}
