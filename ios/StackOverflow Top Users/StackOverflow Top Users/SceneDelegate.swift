import UIKit
import Networking

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?


    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }

        let client = RemoteClient() 
        let userService = StackOverflowUserService(client: client)
        let imageLoader = RemoteImageService(client: client)
        let followStore = UserDefaultsFollowStore()

        let viewModel = UserListViewModel(
            userService: userService,
            followStore: followStore
        )
        let viewController = UserListViewController(
            viewModel: viewModel,
            imageLoader: imageLoader
        )

        let navController = UINavigationController(rootViewController: viewController)

        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = navController
        window.makeKeyAndVisible()
        self.window = window
    }

    func sceneDidDisconnect(_ scene: UIScene) {
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
    }

    func sceneWillResignActive(_ scene: UIScene) {
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
    }

}

