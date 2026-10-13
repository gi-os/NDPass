import XCTest

/// The App Store screenshots, run by `fastlane snapshot` on CI against demo tickets.
final class ScreenshotTests: XCTestCase {
    @MainActor func testScreenshots() {
        continueAfterFailure = true
        let app = XCUIApplication()
        setupSnapshot(app)
        app.launchArguments += ["-demo"]
        app.launchEnvironment["TZ"] = "America/New_York"
        app.launch()
        sleep(3)
        snapshot("01-Tonight")

        let show = app.buttons["Open ticket"]
        if show.waitForExistence(timeout: 5) {
            show.tap(); sleep(2)
            snapshot("02-Ticket")
            let door = app.buttons["Show at the door"]
            if door.waitForExistence(timeout: 5) {
                door.tap(); sleep(2)
                snapshot("03-Door")
                let done = app.buttons["Done"]
                if done.waitForExistence(timeout: 5) { done.tap(); sleep(1) }
            }
            let back = app.navigationBars.buttons.firstMatch
            if back.exists { back.tap(); sleep(1) }
        }
        let collection = app.buttons["Collection"]
        if collection.waitForExistence(timeout: 5) { collection.tap(); sleep(2); snapshot("04-Collection") }
        let calendar = app.buttons["Calendar"]
        if calendar.waitForExistence(timeout: 5) { calendar.tap(); sleep(2); snapshot("05-Calendar") }
    }

    /// App Review's screenshot of the purchase screen (not an App Store screenshot: the
    /// screenshots lane moves it aside for the in-app purchases).
    @MainActor func testPurchaseScreen() {
        continueAfterFailure = true
        let app = XCUIApplication()
        setupSnapshot(app)
        app.launchArguments += ["-demo"]
        app.launch()
        sleep(2)
        let settings = app.buttons["Settings"]
        guard settings.waitForExistence(timeout: 5) else { return XCTFail("no Settings tab") }
        settings.tap(); sleep(1)
        let plus = app.staticTexts["NDPass Gold Plus"]
        var tries = 0
        while !(plus.exists && plus.isHittable) && tries < 8 { app.swipeUp(); tries += 1; sleep(1) }
        snapshot("iap-review")
    }
}
