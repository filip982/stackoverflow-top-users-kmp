import XCTest

/// Acceptance suite (plan §9.12): the real app — real Shared core, Ktor Darwin, NSUserDefaults —
/// against the standalone :mockserver on the Mac host, reached from the simulator at localhost.
///
/// Start the server first (`./gradlew :mockserver:installDist && mockserver/build/install/mockserver/bin/mockserver 8080`)
/// — see iosApp/README.md and the `ios-ui-tests` job in .github/workflows/macos.yml. The app gets the
/// server URL through the `MOCK_BASE_URL` launch environment (debug builds only).
final class AcceptanceTests: XCTestCase {
    private enum Users {
        static let jon: Int64 = 22656
        static let gordon: Int64 = 1_144_035
        static let alex: Int64 = 95810
        static let balusC: Int64 = 157_882
    }

    private let timeout: TimeInterval = 20

    override func setUpWithError() throws {
        continueAfterFailure = false
        try MockServerControl.assertReady()
        try MockServerControl.setScenario("success")
    }

    override func tearDownWithError() throws {
        try? MockServerControl.setScenario("success")
    }

    // MARK: Tests

    func testNavigatesFromListToDetailAndBack() {
        let app = launch()
        tap(row(app, Users.jon))

        let name = element(app, "detail_name")
        XCTAssertTrue(name.waitForExistence(timeout: timeout))
        XCTAssertEqual(name.label, "Jon Skeet")
        XCTAssertEqual(element(app, "detail_reputation").label, "Reputation: 1,520,345")
        XCTAssertTrue(element(app, "detail_location").exists)
        XCTAssertTrue(element(app, "detail_website").exists)

        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(element(app, "user_list").waitForExistence(timeout: timeout))
        XCTAssertTrue(row(app, Users.jon).waitForExistence(timeout: timeout))
    }

    func testFollowPersistsAcrossRelaunch() {
        let first = launch(resetFollows: true)
        XCTAssertTrue(row(first, Users.jon).waitForExistence(timeout: timeout))
        XCTAssertFalse(element(first, "followed_indicator_\(Users.jon)").exists)

        let follow = element(first, "follow_button_\(Users.jon)")
        XCTAssertEqual(follow.label, "Follow")
        follow.tap()
        XCTAssertTrue(element(first, "followed_indicator_\(Users.jon)").waitForExistence(timeout: timeout))
        XCTAssertEqual(element(first, "follow_button_\(Users.jon)").label, "Unfollow")

        // A real process restart: the core is rebuilt from NSUserDefaults.
        first.terminate()
        let second = launch(resetFollows: false)
        XCTAssertTrue(element(second, "followed_indicator_\(Users.jon)").waitForExistence(timeout: timeout))

        // Detail reflects the same persisted state.
        tap(row(second, Users.jon))
        XCTAssertTrue(element(second, "detail_followed_indicator").waitForExistence(timeout: timeout))
    }

    func testFollowFromDetailIsReflectedInTheList() {
        let app = launch()
        tap(row(app, Users.jon))

        let follow = element(app, "detail_follow_button")
        XCTAssertTrue(follow.waitForExistence(timeout: timeout))
        follow.tap()
        XCTAssertTrue(element(app, "detail_followed_indicator").waitForExistence(timeout: timeout))

        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(element(app, "followed_indicator_\(Users.jon)").waitForExistence(timeout: timeout))
    }

    func testSortingAppliesOnApplyAndIsDiscardedOnCancel() {
        let app = launch()
        XCTAssertTrue(row(app, Users.jon).waitForExistence(timeout: timeout))
        XCTAssertTrue(row(app, Users.gordon).waitForExistence(timeout: timeout))
        assertAbove(row(app, Users.jon), row(app, Users.gordon), "reputation desc by default")

        // Cancel discards the draft.
        openSort(app)
        tap(element(app, "sort_field_NAME"))
        tap(element(app, "sort_cancel"))
        waitForDisappearance(element(app, "sort_apply"))
        assertAbove(row(app, Users.jon), row(app, Users.gordon), "cancel keeps reputation order")

        // Apply commits: name ascending puts "Alex Martelli" first.
        openSort(app)
        tap(element(app, "sort_field_NAME"))
        tap(element(app, "sort_direction_asc"))
        tap(element(app, "sort_apply"))
        waitForDisappearance(element(app, "sort_apply"))
        XCTAssertTrue(row(app, Users.alex).waitForExistence(timeout: timeout))
        XCTAssertTrue(row(app, Users.balusC).waitForExistence(timeout: timeout))
        assertAbove(row(app, Users.alex), row(app, Users.balusC), "name asc: Alex Martelli before BalusC")
    }

    func testRetryRecoversFromServerError() throws {
        try MockServerControl.setScenario("error")
        let app = launch()
        XCTAssertTrue(element(app, "error_state").waitForExistence(timeout: timeout))

        try MockServerControl.setScenario("success")
        tap(element(app, "retry_button"))
        XCTAssertTrue(element(app, "user_list").waitForExistence(timeout: timeout))
        XCTAssertTrue(row(app, Users.jon).waitForExistence(timeout: timeout))
    }

    // MARK: Helpers

    private func launch(resetFollows: Bool = true) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["MOCK_BASE_URL"] = MockServerControl.baseUrl
        if resetFollows {
            app.launchEnvironment["RESET_FOLLOWS"] = "1"
        }
        app.launch()
        return app
    }

    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func row(_ app: XCUIApplication, _ id: Int64) -> XCUIElement {
        element(app, "user_row_\(id)")
    }

    private func tap(_ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(element.waitForExistence(timeout: timeout), "\(element) never appeared", file: file, line: line)
        element.tap()
    }

    private func openSort(_ app: XCUIApplication) {
        let button = element(app, "sort_button")
        if button.waitForExistence(timeout: timeout) {
            button.tap()
        } else {
            // Fallback in case the toolbar item does not expose its identifier.
            app.navigationBars.buttons["Sort"].tap()
        }
        XCTAssertTrue(element(app, "sort_apply").waitForExistence(timeout: timeout))
    }

    private func waitForDisappearance(_ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: element)
        XCTAssertEqual(XCTWaiter.wait(for: [gone], timeout: timeout), .completed, "\(element) did not disappear", file: file, line: line)
    }

    private func assertAbove(
        _ upper: XCUIElement,
        _ lower: XCUIElement,
        _ message: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertLessThan(upper.frame.minY, lower.frame.minY, message, file: file, line: line)
    }
}
