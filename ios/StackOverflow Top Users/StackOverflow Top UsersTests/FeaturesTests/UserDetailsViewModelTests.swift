import Testing
import Foundation
@testable import StackOverflow_Top_Users

@MainActor
struct UserDetailsViewModelTests {
    private func user(_ id: Int = 1) -> StackOverflowUser {
        StackOverflowUser(id: id, name: "User \(id)", reputation: 100, profileImageURL: nil, websiteURL: nil)
    }

    @Test func userObjectIsPassed() {
        let vm = UserDetailsViewModel(user: user(), followStore: InMemoryFollowStore())
        #expect(vm.nameString == "User 1")
    }

    @Test func toggleFollowFlipsState() {
        let store = InMemoryFollowStore()
        let vm = UserDetailsViewModel(user: user(99), followStore: store)
        #expect(vm.isFollowed == false)
        vm.toggleFollow()
        #expect(vm.isFollowed == true)
        vm.toggleFollow()
        #expect(vm.isFollowed == false)
    }
}
