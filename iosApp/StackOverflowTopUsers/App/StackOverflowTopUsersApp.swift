import SwiftUI

/// Manual DI root: exactly one shared core (and so one UserRepository) per process.
@main
@MainActor
struct StackOverflowTopUsersApp: App {
    private let gateway: CoreGateway
    private let startupNotice: StartupNotice
    private let isUnitTestHost: Bool

    init() {
        let configuration = AppConfiguration.current
        let defaults = AppConfiguration.followDefaults(reset: configuration.resetFollowState)
        let gateway = SharedCoreGateway(baseUrl: configuration.baseUrl, defaults: defaults)
        self.gateway = gateway
        self.startupNotice = StartupNotice(error: gateway.startupStorageError)
        self.isUnitTestHost = AppConfiguration.isUnitTestHost
    }

    var body: some Scene {
        WindowGroup {
            if isUnitTestHost {
                // Hosting the unit-test bundle: no UI, no network traffic.
                Color.clear
            } else {
                RootView(gateway: gateway, startupNotice: startupNotice)
            }
        }
    }
}

/// Navigation shell: list → detail push, sort as a sheet. The list store is owned here so detail
/// and sort can read/write it, like androidApp's AppNavHost.
struct RootView: View {
    private let gateway: CoreGateway
    @StateObject private var listStore: UserListStore
    @State private var path: [UserModel] = []
    @State private var isSortPresented = false

    init(gateway: CoreGateway, startupNotice: StartupNotice) {
        self.gateway = gateway
        // The autoclosure runs once, when the StateObject is first installed.
        _listStore = StateObject(wrappedValue: UserListStore(gateway: gateway, startupStorageError: startupNotice.take()))
    }

    var body: some View {
        NavigationStack(path: $path) {
            UserListView(
                store: listStore,
                onSelect: { path.append($0) },
                onSort: { isSortPresented = true }
            )
            .navigationDestination(for: UserModel.self) { user in
                UserDetailView(user: user, gateway: gateway)
            }
        }
        .sheet(isPresented: $isSortPresented) {
            SortOptionsView(initial: listStore.state.sort) { option in
                listStore.dispatch(.applySort(option))
            }
        }
    }
}
