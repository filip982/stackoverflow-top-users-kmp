import Foundation

/// Stable accessibility identifiers shared by the SwiftUI views and the XCUITest suite.
/// Same strings as androidApp's TestTags.
enum AccessibilityID {
    static let userList = "user_list"
    static let loading = "loading"
    static let errorState = "error_state"
    static let emptyState = "empty_state"
    static let retry = "retry_button"
    static let sortButton = "sort_button"
    static let messageBanner = "message_banner"

    static let detailName = "detail_name"
    static let detailReputation = "detail_reputation"
    static let detailLocation = "detail_location"
    static let detailWebsite = "detail_website"
    static let detailFollow = "detail_follow_button"
    static let detailFollowedIndicator = "detail_followed_indicator"

    static let sortDirectionAsc = "sort_direction_asc"
    static let sortDirectionDesc = "sort_direction_desc"
    static let sortApply = "sort_apply"
    static let sortCancel = "sort_cancel"

    static func userRow(_ id: Int64) -> String { "user_row_\(id)" }
    static func followButton(_ id: Int64) -> String { "follow_button_\(id)" }
    static func followedIndicator(_ id: Int64) -> String { "followed_indicator_\(id)" }
    static func sortField(_ name: String) -> String { "sort_field_\(name)" }
}

enum Formatting {
    private static let reputationFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = true
        formatter.locale = Locale(identifier: "en_US")
        return formatter
    }()

    /// `1520345` → `"1,520,345"` (fixed grouping so UI tests are locale-independent).
    static func reputation(_ value: Int64) -> String {
        reputationFormatter.string(from: NSNumber(value: value)) ?? String(value)
    }
}

extension CoreErrorModel {
    /// Same copy as androidApp's `coreErrorText`.
    var userText: String {
        switch self {
        case .network:
            return "Can't reach Stack Overflow. Check your connection and try again."
        case let .http(code, apiMessage):
            let base = "Stack Overflow returned an error (HTTP \(code))."
            return apiMessage.map { "\(base)\n\($0)" } ?? base
        case .decoding:
            return "Received an unexpected response from Stack Overflow."
        case .storage:
            return "Couldn't save your follow changes on this device."
        }
    }
}

extension UserMessage {
    var text: String {
        switch self {
        case let .followFailed(_, error):
            return "Couldn't update follow. \(error.userText)"
        case .followStateReset:
            return "Your saved follows could not be read and were reset."
        }
    }
}
