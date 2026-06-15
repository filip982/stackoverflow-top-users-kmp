import Foundation

@MainActor
final class UserListViewModel {

    private let userService: any UserService

    init(userService: any UserService) {
        self.userService = userService
    }

    func load() async {
        do {
            let users = try await userService.topUsers()
            if users.isEmpty {
                debugPrint("🙈 No users")
            } else {
                debugPrint("✅ Success: \(users.count) users fetched")
            }
        } catch {
            debugPrint("🔴 Error: \(error.localizedDescription)")
        }
    }
}
