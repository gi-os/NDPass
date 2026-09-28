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

        let show = app.buttons["Show ticket"]
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
}
