import XCTest
@testable import StackOverflowTopUsers

/// Mirrors androidApp's UserListStoreTest: same behaviours, same invariants (plan §9.9).
@MainActor
final class UserListStoreTests: XCTestCase {
    private typealias Users = FixtureUsers

    private func makeStore(
        _ gateway: FakeCoreGateway,
        startupStorageError: CoreErrorModel? = nil
    ) -> UserListStore {
        UserListStore(gateway: gateway, startupStorageError: startupStorageError)
    }

    /// Store effects start asynchronously: wait for the fetch to reach the fake, then answer it.
    private func completeFetch(
        _ gateway: FakeCoreGateway,
        _ index: Int,
        _ result: FakeCoreGateway.UsersResult,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        await waitUntil("fetch #\(index) never reached the core", file: file, line: line) { gateway.hasPendingFetch(index) }
        gateway.completeFetch(index, with: result)
    }

    // MARK: Loading / content / empty / error

    func testInitialLoadGoesLoadingThenContentSortedByReputationDesc() async {
        let gateway = FakeCoreGateway()
        let store = makeStore(gateway)

        XCTAssertEqual(store.state.status, .loading)
        await waitUntil { gateway.hasPendingFetch(0) }
        XCTAssertEqual(gateway.fetchRequests, [.default], "first fetch asks the core for reputation desc")

        await completeFetch(gateway, 0, .success(Users.all))
        await waitUntil { store.state.status == .content }

        XCTAssertEqual(store.state.users, Users.byReputationDesc)
    }

    func testEmptySuccessIsEmptyNotAnError() async {
        let gateway = FakeCoreGateway()
        let store = makeStore(gateway)

        await completeFetch(gateway, 0, .success([]))
        await waitUntil { store.state.status != .loading }

        XCTAssertEqual(store.state.status, .empty)
        XCTAssertTrue(store.state.users.isEmpty)
    }

    func testFailureIsFailedWithTheTypedCoreError() async {
        let gateway = FakeCoreGateway()
        let store = makeStore(gateway)

        await completeFetch(gateway, 0, .failure(.http(code: 400, apiMessage: "throttle violation")))
        await waitUntil { store.state.status != .loading }

        XCTAssertEqual(store.state.status, .failed(.http(code: 400, apiMessage: "throttle violation")))
        XCTAssertTrue(store.state.users.isEmpty)
    }

    func testRetryAfterAnErrorRecoversToContent() async {
        let gateway = FakeCoreGateway()
        let store = makeStore(gateway)
        await completeFetch(gateway, 0, .failure(.network(message: "offline")))
        await waitUntil { store.state.status == .failed(.network(message: "offline")) }

        store.dispatch(.retry)
        XCTAssertEqual(store.state.status, .loading, "retry shows loading again")

        await completeFetch(gateway, 1, .success(Users.all))
        await waitUntil { store.state.status == .content }
        XCTAssertEqual(store.state.users, Users.byReputationDesc)
    }

    // MARK: Latest request wins

    func testStaleCompletionOfAnOlderRequestIsSuppressed() async {
        let gateway = FakeCoreGateway()
        let store = makeStore(gateway)
        store.dispatch(.retry) // second request supersedes the first while both are in flight
        await waitUntil { gateway.pendingFetchCount == 2 }

        await completeFetch(gateway, 1, .success([Users.jon]))
        await waitUntil { store.state.status == .content }
        XCTAssertEqual(store.state.users, [Users.jon])

        // The older request finishes last, with a different answer: it must not win.
        await completeFetch(gateway, 0, .failure(.network(message: "late")))
        await settle()
        XCTAssertEqual(store.state.status, .content)
        XCTAssertEqual(store.state.users, [Users.jon])
    }

    func testReducerIgnoresLoadFinishedForARequestThatIsNoLongerActive() {
        var state = UserListState()
        state = UserListReducer.reduce(state, .loadStarted(requestId: 2))

        let stale = UserListReducer.reduce(state, .loadFinished(requestId: 1, result: .success([Users.jon])))

        XCTAssertEqual(stale, state)
    }

    // MARK: Follow (rapid-toggle policy, failures, sync)

    func testRapidTogglesOnTheSameUserWhileOneIsInFlightAreDropped() async {
        let gateway = FakeCoreGateway()
        let store = makeStore(gateway)
        await completeFetch(gateway, 0, .success(Users.all))
        await waitUntil { store.state.status == .content }

        store.dispatch(.toggleFollow(userId: Users.jon.id))
        store.dispatch(.toggleFollow(userId: Users.jon.id))
        store.dispatch(.toggleFollow(userId: Users.jon.id))
        await waitUntil { gateway.pendingToggleCount == 1 }
        await settle()

        XCTAssertEqual(gateway.toggleRequests, [Users.jon.id], "only the first tap reaches the core")
        XCTAssertEqual(store.state.pendingFollowIds, [Users.jon.id])

        gateway.completeToggle(0)
        await waitUntil { store.state.pendingFollowIds.isEmpty }
        XCTAssertEqual(store.state.followedIds, [Users.jon.id])

        // Once settled, the user can be toggled again.
        store.dispatch(.toggleFollow(userId: Users.jon.id))
        await waitUntil { gateway.pendingToggleCount == 1 }
        gateway.completeToggle(1)
        await waitUntil { store.state.followedIds.isEmpty && store.state.pendingFollowIds.isEmpty }
    }

    func testRapidTogglesOnDifferentUsersAreAllApplied() async {
        let gateway = FakeCoreGateway()
        gateway.immediateToggles = true
        let store = makeStore(gateway)
        await completeFetch(gateway, 0, .success(Users.all))
        await waitUntil { store.state.status == .content }

        store.dispatch(.toggleFollow(userId: Users.jon.id))
        store.dispatch(.toggleFollow(userId: Users.alex.id))
        await waitUntil { store.state.followedIds == [Users.jon.id, Users.alex.id] }

        XCTAssertEqual(Set(gateway.toggleRequests), [Users.jon.id, Users.alex.id])
        await waitUntil { store.state.pendingFollowIds.isEmpty }
    }

    func testFollowFailureIsSurfacedAndFollowStateIsUnchanged() async {
        let gateway = FakeCoreGateway()
        gateway.immediateToggles = true
        gateway.toggleError = .storage(message: "disk full")
        let store = makeStore(gateway)
        await completeFetch(gateway, 0, .success(Users.all))
        await waitUntil { store.state.status == .content }

        store.dispatch(.toggleFollow(userId: Users.jon.id))
        await waitUntil { store.state.message != nil }

        XCTAssertEqual(store.state.message, .followFailed(userId: Users.jon.id, error: .storage(message: "disk full")))
        XCTAssertTrue(store.state.followedIds.isEmpty)
        XCTAssertTrue(store.state.pendingFollowIds.isEmpty)

        store.dispatch(.messageShown)
        XCTAssertNil(store.state.message)
    }

    func testFollowChangesMadeElsewhereAreReflected() async {
        let gateway = FakeCoreGateway(followed: [Users.gordon.id])
        gateway.immediateFetchResult = .success(Users.all)
        let store = makeStore(gateway)
        XCTAssertEqual(store.state.followedIds, [Users.gordon.id], "initial snapshot comes from the repository")

        gateway.externalFollowChange([Users.jon.id])
        await waitUntil { store.state.followedIds == [Users.jon.id] }
    }

    func testStartupStorageErrorIsSurfacedOnce() async {
        let gateway = FakeCoreGateway()
        gateway.immediateFetchResult = .success([])
        let store = makeStore(gateway, startupStorageError: .storage(message: "corrupt"))

        XCTAssertEqual(store.state.message, .followStateReset(.storage(message: "corrupt")))
        store.dispatch(.messageShown)
        XCTAssertNil(store.state.message)
    }

    func testStartupNoticeHandsTheErrorOutOnlyOnce() {
        let notice = StartupNotice(error: .storage(message: "corrupt"))
        XCTAssertEqual(notice.take(), .storage(message: "corrupt"))
        XCTAssertNil(notice.take())
    }

    // MARK: Sorting

    func testApplyingASortReSortsLoadedUsersWithoutRefetching() async {
        let gateway = FakeCoreGateway()
        let store = makeStore(gateway)
        await completeFetch(gateway, 0, .success(Users.all))
        await waitUntil { store.state.status == .content }

        let byName = SortOptionModel(field: .name, direction: .asc)
        store.dispatch(.applySort(byName))

        XCTAssertEqual(store.state.sort, byName)
        XCTAssertEqual(store.state.users, Users.byNameAsc)
        XCTAssertEqual(gateway.fetchRequests.count, 1, "sorting is client-side")
    }

    func testASortAppliedWhileLoadingIsHonouredByTheLoadResult() async {
        let gateway = FakeCoreGateway()
        let store = makeStore(gateway)
        let byName = SortOptionModel(field: .name, direction: .asc)

        store.dispatch(.applySort(byName)) // request #0 is still in flight with reputation desc
        await completeFetch(gateway, 0, .success(Users.all))
        await waitUntil { store.state.status == .content }

        XCTAssertEqual(store.state.sort, byName)
        XCTAssertEqual(store.state.users, Users.byNameAsc)
    }

    func testRetryFetchesWithTheCurrentSort() async {
        let gateway = FakeCoreGateway()
        let store = makeStore(gateway)
        await completeFetch(gateway, 0, .success(Users.all))
        await waitUntil { store.state.status == .content }
        let byName = SortOptionModel(field: .name, direction: .asc)
        store.dispatch(.applySort(byName))

        store.dispatch(.retry)

        await completeFetch(gateway, 1, .success(Users.all))
        XCTAssertEqual(gateway.fetchRequests.last, byName)
        await waitUntil { store.state.status == .content }
        XCTAssertEqual(store.state.users, Users.byNameAsc)
    }

    // MARK: Lifecycle

    func testFollowObservationIsDisposedWhenTheStoreIsReleased() async {
        let gateway = FakeCoreGateway()
        gateway.immediateFetchResult = .success(Users.all)
        var store: UserListStore? = makeStore(gateway)
        await waitUntil { store?.state.status == .content }
        XCTAssertEqual(gateway.activeObserverCount, 1)

        store = nil

        await waitUntil { gateway.activeObserverCount == 0 }
    }
}
