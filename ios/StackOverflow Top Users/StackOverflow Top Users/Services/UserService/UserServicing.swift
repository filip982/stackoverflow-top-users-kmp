import Foundation

public protocol UserServicing: Sendable {
    func topUsers(sort: SortConfiguration) async throws -> [StackOverflowUser]
}
