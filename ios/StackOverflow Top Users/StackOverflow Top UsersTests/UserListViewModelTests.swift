import Testing
import Foundation
@testable import StackOverflow_Top_Users

private final class FakeUserService: UserServicing, @unchecked Sendable {
    var result: Result<[StackOverflowUser], Error> = .success([])
    func topUsers() async throws -> [StackOverflowUser] { try result.get() }
}

private final class InMemoryFollowStore: FollowStoring, @unchecked Sendable {
    private var ids: Set<Int> = []
    func isFollowed(_ id: Int) -> Bool { ids.contains(id) }
    func setFollowed(_ followed: Bool, for id: Int) {
        if followed { ids.insert(id) } else { ids.remove(id) }
    }
}

@MainActor
struct UserListViewModelTests {
    private func user(_ id: Int) -> StackOverflowUser {
        StackOverflowUser(id: id, name: "User \(id)", reputation: 100, profileImageURL: nil)
    }

    @Test func loadsUsersIntoLoadedState() async {
        let service = FakeUserService()
        service.result = .success([user(1), user(2)])
        let vm = UserListViewModel(userService: service, followStore: InMemoryFollowStore())
        await vm.load()
        if case .loaded(let users) = vm.state { #expect(users.count == 2) }
        else { Issue.record("expected .loaded") }
    }

    @Test func emptyResultBecomesError() async {
        let service = FakeUserService()
        service.result = .success([])
        let vm = UserListViewModel(userService: service, followStore: InMemoryFollowStore())
        await vm.load()
        if case .error = vm.state {} else { Issue.record("expected .error") }
    }

    @Test func throwBecomesError() async {
        let service = FakeUserService()
        service.result = .failure(URLError(.notConnectedToInternet))
        let vm = UserListViewModel(userService: service, followStore: InMemoryFollowStore())
        await vm.load()
        if case .error = vm.state {} else { Issue.record("expected .error") }
    }

    @Test func toggleFollowFlipsState() {
        let vm = UserListViewModel(userService: FakeUserService(), followStore: InMemoryFollowStore())
        let u = user(99)
        #expect(vm.isFollowed(u) == false)
        vm.toggleFollow(u)
        #expect(vm.isFollowed(u) == true)
        vm.toggleFollow(u)
        #expect(vm.isFollowed(u) == false)
    }
}
