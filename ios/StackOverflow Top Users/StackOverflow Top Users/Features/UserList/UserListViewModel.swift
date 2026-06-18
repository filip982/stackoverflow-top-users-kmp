import Foundation

@MainActor
final class UserListViewModel {
    enum State {
        case loading
        case loaded([StackOverflowUser])
        case error(String)
    }

    private(set) var state: State = .loading {
        didSet { onChange?() }
    }

    var onChange: (() -> Void)?

    private let userService: any UserServicing
    private let followStore: any FollowStoring
    private weak var coordinator: AppCoordinator?
    private(set) var currentSort = SortConfiguration()

    init(userService: any UserServicing, followStore: any FollowStoring, coordinator: AppCoordinator? = nil) {
        self.userService = userService
        self.followStore = followStore
        self.coordinator = coordinator
    }

    func load() async {
        state = .loading
        do {
            let users = try await userService.topUsers(sort: currentSort)
            state = users.isEmpty ? .error("No users found.") : .loaded(users)
        } catch {
            state = .error("Couldn't load users. Check your connection and try again.")
        }
    }

    func applySort(_ sort: SortConfiguration) {
        currentSort = sort
        Task { await self.load() }
    }

    func isFollowed(_ user: StackOverflowUser) -> Bool {
        followStore.isFollowed(user.id)
    }

    func toggleFollow(_ user: StackOverflowUser) {
        let newValue = !followStore.isFollowed(user.id)
        followStore.setFollowed(newValue, for: user.id)
    }

    func showUserDetails(_ user: StackOverflowUser) {
        coordinator?.showUserDetails(for: user)
    }
}
