import Testing
import Foundation
@testable import StackOverflow_Top_Users

@MainActor
struct UserDetailsViewModelTests {
    private func user(
        id: Int = 1,
        name: String = "Jon Skeet",
        reputation: Int = 1_000_000,
        profileImageURL: URL? = URL(string: "https://example.com/avatar.jpg"),
        websiteURL: URL? = URL(string: "https://example.com"),
        location: String? = "Reading, UK"
    ) -> StackOverflowUser {
        StackOverflowUser(id: id, name: name, reputation: reputation, profileImageURL: profileImageURL, websiteURL: websiteURL, location: location)
    }

    @Test func exposesName() {
        let vm = UserDetailsViewModel(user: user(name: "Jon Skeet"), followStore: InMemoryFollowStore())
        #expect(vm.nameString == "Jon Skeet")
    }

    @Test func exposesFormattedReputation() {
        let vm = UserDetailsViewModel(user: user(reputation: 1_000_000), followStore: InMemoryFollowStore())
        #expect(vm.repString.contains("1"))
    }

    @Test func exposesLocation() {
        let vm = UserDetailsViewModel(user: user(location: "London, UK"), followStore: InMemoryFollowStore())
        #expect(vm.locationString == "London, UK")
    }

    @Test func missingLocationShowsFallback() {
        let vm = UserDetailsViewModel(user: user(location: nil), followStore: InMemoryFollowStore())
        #expect(vm.locationString == "Location not available")
    }

    @Test func exposesWebsiteURL() {
        let url = URL(string: "https://example.com")!
        let vm = UserDetailsViewModel(user: user(websiteURL: url), followStore: InMemoryFollowStore())
        #expect(vm.websiteURL == url)
    }

    @Test func missingWebsiteURLIsNil() {
        let vm = UserDetailsViewModel(user: user(websiteURL: nil), followStore: InMemoryFollowStore())
        #expect(vm.websiteURL == nil)
    }

    @Test func exposesProfileImageURL() {
        let url = URL(string: "https://example.com/avatar.jpg")!
        let vm = UserDetailsViewModel(user: user(profileImageURL: url), followStore: InMemoryFollowStore())
        #expect(vm.profileImageURL == url)
    }

    @Test func toggleFollowFlipsState() {
        let vm = UserDetailsViewModel(user: user(), followStore: InMemoryFollowStore())
        #expect(vm.isFollowed == false)
        vm.toggleFollow()
        #expect(vm.isFollowed == true)
        vm.toggleFollow()
        #expect(vm.isFollowed == false)
    }

    @Test func followStateIsPerUser() {
        let store = InMemoryFollowStore()
        let vm1 = UserDetailsViewModel(user: user(id: 1), followStore: store)
        let vm2 = UserDetailsViewModel(user: user(id: 2), followStore: store)
        vm1.toggleFollow()
        #expect(vm1.isFollowed == true)
        #expect(vm2.isFollowed == false)
    }
}
