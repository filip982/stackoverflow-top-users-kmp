import Foundation

public protocol UserServicing: Sendable {
    func topUsers() async throws -> [StackOverflowUser]
}
