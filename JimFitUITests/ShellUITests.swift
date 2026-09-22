import XCTest

// These drive the live https://jimfit.app, so timeouts allow for a slow network. None of them log in.
@MainActor
final class ShellUITests: XCTestCase {
    private let network: TimeInterval = 45
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        app = XCUIApplication()
    }

    override func tearDown() async throws {
        XCUIDevice.shared.orientation = .portrait
        app.terminate()
    }

    private func launchToWelcome() {
        app.launch()
        XCTAssertTrue(app.staticTexts["Welcome to JimFit"].waitForExistence(timeout: network), "welcome screen never rendered")
    }

    private func openLoginChoice() -> XCUIElement {
        launchToWelcome()
        app.buttons["Get started"].tap()
        let prompt = app.staticTexts["How are you logging in?"]
        XCTAssertTrue(prompt.waitForExistence(timeout: 15))
        return prompt
    }

    func testLaunchShowsWelcomeScreen() {
        launchToWelcome()
        XCTAssertTrue(app.buttons["Get started"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["Can't reach JimFit"].exists)
    }

    func testGetStartedOpensLoginChoice() {
        _ = openLoginChoice()
        XCTAssertTrue(app.buttons["I'm a Member"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["I'm a Trainer"].exists)
    }

    func testPrivacyPolicyStaysInApp() {
        launchToWelcome()
        let privacy = app.buttons["Privacy Policy"]
        XCTAssertTrue(privacy.waitForExistence(timeout: 10))
        privacy.tap()
        XCTAssertTrue(app.staticTexts["Last updated September 2026"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.state, .runningForeground)
    }

    func testRotationKeepsLoginChoice() {
        let prompt = openLoginChoice()
        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(prompt.waitForExistence(timeout: 10))
        XCUIDevice.shared.orientation = .portrait
        XCTAssertTrue(prompt.waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["Welcome to JimFit"].exists)
    }

    func testUnreachableHostShowsErrorAndRetry() {
        app.launchArguments = ["-JimFitBaseURL", "https://jimfit.invalid"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Can't reach JimFit"].waitForExistence(timeout: network))
        let retry = app.buttons["Retry"]
        XCTAssertTrue(retry.exists)

        retry.tap()
        XCTAssertTrue(app.staticTexts["Can't reach JimFit"].waitForExistence(timeout: network))
        XCTAssertTrue(app.buttons["Retry"].exists)
    }
}
