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

    private let userService: any UserService

    init(userService: any UserService) {
        self.userService = userService
    }

    func load() async {
        state = .loading
        do {
            let users = try await userService.topUsers()
            state = users.isEmpty ? .error("No users found.") : .loaded(users)
        } catch {
            state = .error("Couldn't load users. Check your connection and try again.")
        }
    }
}
