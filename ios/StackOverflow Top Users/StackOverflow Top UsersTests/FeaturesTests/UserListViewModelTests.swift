import Testing
import Foundation
@testable import StackOverflow_Top_Users

@MainActor
struct UserListViewModelTests {
    private func user(_ id: Int) -> StackOverflowUser {
        StackOverflowUser(id: id, name: "User \(id)", reputation: 100, profileImageURL: nil, websiteURL: nil)
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

    @Test func defaultSortIsReputationDescending() {
        let vm = UserListViewModel(userService: FakeUserService(), followStore: InMemoryFollowStore())
        #expect(vm.currentSort == SortConfiguration())
        #expect(vm.currentSort.option == .reputation)
        #expect(vm.currentSort.order == .descending)
    }

    @Test func applySortUpdatesSortAndLoads() async {
        let service = FakeUserService()
        service.result = .success([user(1)])
        let vm = UserListViewModel(userService: service, followStore: InMemoryFollowStore())
        let newSort = SortConfiguration(option: .name, order: .ascending)
        vm.applySort(newSort)
        #expect(vm.currentSort == newSort)
        // give the async load a moment to settle
        try? await Task.sleep(nanoseconds: 100_000_000)
        if case .loaded = vm.state {} else { Issue.record("expected .loaded after applySort") }
    }
}
