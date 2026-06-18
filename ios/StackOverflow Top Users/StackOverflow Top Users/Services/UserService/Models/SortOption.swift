import Foundation

enum SortOption: String, CaseIterable, Equatable, Sendable {
    case reputation
    case name
    case creation
    case modified

    var title: String {
        switch self {
        case .reputation: return "Reputation"
        case .name:       return "Name"
        case .creation:   return "Date Created"
        case .modified:   return "Date Updated"
        }
    }
}

enum SortOrder: String, CaseIterable, Equatable, Sendable {
    case descending = "desc"
    case ascending  = "asc"

    var title: String {
        switch self {
        case .descending: return "Descending"
        case .ascending:  return "Ascending"
        }
    }
}

struct SortConfiguration: Equatable, Sendable {
    var option: SortOption = .reputation
    var order: SortOrder   = .descending
}
