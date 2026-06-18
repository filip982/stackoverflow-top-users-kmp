import Foundation

@MainActor
final class UserDetailsViewModel {
    let nameString: String
    let repString: String

    private let user: StackOverflowUser
    private let followStore: any FollowStoring

    init(user: StackOverflowUser, followStore: any FollowStoring) {
        self.user = user
        self.followStore = followStore
        nameString = user.name
        repString = "rep " + user.reputation.formatted(.number.grouping(.automatic))
    }

    var isFollowed: Bool {
        followStore.isFollowed(user.id)
    }

    func toggleFollow() {
        let newValue = !followStore.isFollowed(user.id)
        followStore.setFollowed(newValue, for: user.id)
    }
}
