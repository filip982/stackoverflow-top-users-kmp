import Testing
import Foundation
@testable import StackOverflow_Top_Users

final class FakeUserService: UserServicing, @unchecked Sendable {
    var result: Result<[StackOverflowUser], Error> = .success([])
    func topUsers(sort: SortConfiguration) async throws -> [StackOverflowUser] { try result.get() }
}

final class InMemoryFollowStore: FollowStoring, @unchecked Sendable {
    private var ids: Set<Int> = []
    func isFollowed(_ id: Int) -> Bool { ids.contains(id) }
    func setFollowed(_ followed: Bool, for id: Int) {
        if followed { ids.insert(id) } else { ids.remove(id) }
    }
}
