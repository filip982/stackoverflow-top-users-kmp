import Foundation

/// Process-level configuration, resolved once in the App initializer.
///
/// Base URL precedence (debug builds only; release builds always use production):
/// 1. `MOCK_BASE_URL` launch environment variable (XCUITest / Xcode scheme),
/// 2. `MockBaseURL` Info.plist key, filled from the `MOCK_BASE_URL` build setting (Config/Debug.xcconfig),
/// 3. the production StackExchange API.
struct AppConfiguration: Equatable {
    static let productionBaseUrl = "https://api.stackexchange.com"
    static let baseUrlEnvironmentKey = "MOCK_BASE_URL"
    static let baseUrlInfoKey = "MockBaseURL"
    /// Launch-environment flag (debug only): start from an empty follow store. Used by XCUITests.
    static let resetFollowsEnvironmentKey = "RESET_FOLLOWS"
    /// UserDefaults suite holding the persisted follow ids (the shared core's settings store).
    static let followDefaultsSuiteName = "so_top_users"

    let baseUrl: String
    let resetFollowState: Bool

    /// Pure resolution, unit-tested. `allowOverrides` is true only in DEBUG builds.
    static func resolve(
        environment: [String: String],
        infoDictionary: [String: Any],
        allowOverrides: Bool
    ) -> AppConfiguration {
        guard allowOverrides else {
            return AppConfiguration(baseUrl: productionBaseUrl, resetFollowState: false)
        }
        let candidates: [String?] = [
            environment[baseUrlEnvironmentKey],
            infoDictionary[baseUrlInfoKey] as? String,
        ]
        let override = candidates.lazy.compactMap { $0.flatMap(validBaseUrl) }.first
        let reset = ["1", "true", "yes"].contains(environment[resetFollowsEnvironmentKey]?.lowercased() ?? "")
        return AppConfiguration(baseUrl: override ?? productionBaseUrl, resetFollowState: reset)
    }

    static var current: AppConfiguration {
        #if DEBUG
        let allowOverrides = true
        #else
        let allowOverrides = false
        #endif
        return resolve(
            environment: ProcessInfo.processInfo.environment,
            infoDictionary: Bundle.main.infoDictionary ?? [:],
            allowOverrides: allowOverrides
        )
    }

    /// True when this process is the host app of the unit-test bundle (not a UI-test launch).
    static var isUnitTestHost: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    /// The follow store's defaults suite; optionally wiped first (debug/UI-test only).
    static func followDefaults(reset: Bool) -> UserDefaults {
        let defaults = UserDefaults(suiteName: followDefaultsSuiteName) ?? .standard
        if reset {
            defaults.removePersistentDomain(forName: followDefaultsSuiteName)
            defaults.synchronize()
        }
        return defaults
    }

    /// Accepts absolute http(s) URLs with a host; rejects blanks and unexpanded `$(VAR)` placeholders.
    private static func validBaseUrl(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.contains("$("),
              let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https",
              let host = url.host, !host.isEmpty
        else { return nil }
        return trimmed
    }
}

/// Hands out the startup storage error at most once, so it is shown a single time per process.
@MainActor
final class StartupNotice {
    private var error: CoreErrorModel?

    init(error: CoreErrorModel?) {
        self.error = error
    }

    func take() -> CoreErrorModel? {
        defer { error = nil }
        return error
    }
}
