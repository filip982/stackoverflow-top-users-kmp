import Foundation

public protocol UserService: Sendable {
    func topUsers() async throws -> [StackOverflowUser]
}
