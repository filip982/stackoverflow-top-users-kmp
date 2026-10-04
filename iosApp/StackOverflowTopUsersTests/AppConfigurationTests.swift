import XCTest
@testable import StackOverflowTopUsers

/// Base-URL injection is debug-only (plan §9.10): release builds can never be pointed elsewhere.
final class AppConfigurationTests: XCTestCase {
    private let production = AppConfiguration.productionBaseUrl

    func testReleaseAlwaysUsesProductionAndNeverResets() {
        let config = AppConfiguration.resolve(
            environment: ["MOCK_BASE_URL": "http://localhost:8080", "RESET_FOLLOWS": "1"],
            infoDictionary: ["MockBaseURL": "http://localhost:8080"],
            allowOverrides: false
        )

        XCTAssertEqual(config, AppConfiguration(baseUrl: production, resetFollowState: false))
    }

    func testDebugDefaultsToProduction() {
        let config = AppConfiguration.resolve(environment: [:], infoDictionary: [:], allowOverrides: true)

        XCTAssertEqual(config.baseUrl, production)
        XCTAssertFalse(config.resetFollowState)
    }

    func testDebugLaunchEnvironmentWinsOverInfoPlist() {
        let config = AppConfiguration.resolve(
            environment: ["MOCK_BASE_URL": "http://localhost:8080"],
            infoDictionary: ["MockBaseURL": "http://localhost:9090"],
            allowOverrides: true
        )

        XCTAssertEqual(config.baseUrl, "http://localhost:8080")
    }

    func testDebugInfoPlistOverrideIsUsedWhenNoEnvironment() {
        let config = AppConfiguration.resolve(
            environment: [:],
            infoDictionary: ["MockBaseURL": "http://localhost:9090"],
            allowOverrides: true
        )

        XCTAssertEqual(config.baseUrl, "http://localhost:9090")
    }

    func testBlankOrUnexpandedOrNonHttpOverridesAreIgnored() {
        for bad in ["", "   ", "$(MOCK_BASE_URL)", "localhost:8080", "ftp://localhost", "http://"] {
            let config = AppConfiguration.resolve(
                environment: ["MOCK_BASE_URL": bad],
                infoDictionary: ["MockBaseURL": bad],
                allowOverrides: true
            )
            XCTAssertEqual(config.baseUrl, production, "override '\(bad)' must be ignored")
        }
    }

    func testResetFlagIsReadFromTheLaunchEnvironmentInDebug() {
        let on = AppConfiguration.resolve(environment: ["RESET_FOLLOWS": "1"], infoDictionary: [:], allowOverrides: true)
        let off = AppConfiguration.resolve(environment: ["RESET_FOLLOWS": "0"], infoDictionary: [:], allowOverrides: true)

        XCTAssertTrue(on.resetFollowState)
        XCTAssertFalse(off.resetFollowState)
    }

    func testReputationIsFormattedWithFixedGrouping() {
        XCTAssertEqual(Formatting.reputation(1_520_345), "1,520,345")
        XCTAssertEqual(Formatting.reputation(999), "999")
    }

    func testErrorCopyMatchesAndroid() {
        XCTAssertEqual(
            CoreErrorModel.http(code: 400, apiMessage: "throttle violation").userText,
            "Stack Overflow returned an error (HTTP 400).\nthrottle violation"
        )
        XCTAssertEqual(
            CoreErrorModel.network(message: nil).userText,
            "Can't reach Stack Overflow. Check your connection and try again."
        )
    }
}
