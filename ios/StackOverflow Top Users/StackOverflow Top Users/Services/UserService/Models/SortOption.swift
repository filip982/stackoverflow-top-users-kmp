import Foundation

public enum SortOption: String, CaseIterable, Equatable, Sendable {
    case reputation
    case name
    case creation
    case modified

    public var title: String {
        switch self {
        case .reputation: return "Reputation"
        case .name:       return "Name"
        case .creation:   return "Date Created"
        case .modified:   return "Date Updated"
        }
    }
}

public enum SortOrder: String, CaseIterable, Equatable, Sendable {
    case descending = "desc"
    case ascending  = "asc"

    public var title: String {
        switch self {
        case .descending: return "Descending"
        case .ascending:  return "Ascending"
        }
    }
}

public struct SortConfiguration: Equatable, Sendable {
    public var option: SortOption = .reputation
    public var order: SortOrder   = .descending

    public init(option: SortOption = .reputation, order: SortOrder = .descending) {
        self.option = option
        self.order = order
    }
}
