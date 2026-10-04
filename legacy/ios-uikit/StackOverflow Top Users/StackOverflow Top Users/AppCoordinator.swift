import UIKit
import Networking

class AppCoordinator {

    let client = RemoteClient()
    private lazy var userService = StackOverflowUserService(client: client)
    private lazy var imageLoader = RemoteImageService(client: client)
    private lazy var followStore = UserDefaultsFollowStore()

    public var navController = UINavigationController()

    init () {
        let userListViewModel = UserListViewModel(
            userService: userService,
            followStore: followStore,
            coordinator: self
        )
        let userListViewController = UserListViewController(
            viewModel: userListViewModel,
            imageLoader: imageLoader
        )
        self.navController.viewControllers = [userListViewController]
    }

    func showUserDetails(for user: StackOverflowUser) {
        let viewModel = UserDetailsViewModel(user: user, followStore: followStore)
        let viewController = UserDetailsViewController(viewModel: viewModel, imageLoader: imageLoader)
        self.navController.pushViewController(viewController, animated: true)
    }
}
