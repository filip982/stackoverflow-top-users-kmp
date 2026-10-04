import XCTest
@testable import StackOverflowTopUsers

/// Mirrors androidApp's UserDetailStoreTest.
@MainActor
final class UserDetailStoreTests: XCTestCase {
    private let jon = FixtureUsers.jon

    func testInitialFollowStateComesFromTheRepository() {
        let followed = UserDetailStore(user: jon, gateway: FakeCoreGateway(followed: [jon.id]))
        let notFollowed = UserDetailStore(user: jon, gateway: FakeCoreGateway(followed: [FixtureUsers.alex.id]))

        XCTAssertTrue(followed.state.isFollowed)
        XCTAssertFalse(notFollowed.state.isFollowed)
        XCTAssertEqual(followed.state.user, jon)
    }

    func testToggleFollowsWithAPendingPhaseThenUnfollows() async {
        let gateway = FakeCoreGateway()
        let store = UserDetailStore(user: jon, gateway: gateway)

        store.dispatch(.toggleFollow)
        XCTAssertTrue(store.state.isTogglePending)
        await waitUntil { gateway.hasPendingToggle(0) }
        gateway.completeToggle(0)
        await waitUntil { !store.state.isTogglePending }
        XCTAssertTrue(store.state.isFollowed)

        store.dispatch(.toggleFollow)
        await waitUntil { gateway.hasPendingToggle(1) }
        gateway.completeToggle(1)
        await waitUntil { !store.state.isTogglePending }
        XCTAssertFalse(store.state.isFollowed)
    }

    func testRapidTogglesWhileOneIsInFlightAreDropped() async {
        let gateway = FakeCoreGateway()
        let store = UserDetailStore(user: jon, gateway: gateway)

        store.dispatch(.toggleFollow)
        store.dispatch(.toggleFollow)
        store.dispatch(.toggleFollow)
        await waitUntil { gateway.hasPendingToggle(0) }
        await settle()

        XCTAssertEqual(gateway.toggleRequests, [jon.id])
        gateway.completeToggle(0)
        await waitUntil { !store.state.isTogglePending }
        XCTAssertTrue(store.state.isFollowed, "exactly one flip happened")
    }

    func testFollowFailureIsSurfaced() async {
        let gateway = FakeCoreGateway()
        gateway.immediateToggles = true
        gateway.toggleError = .storage(message: "disk full")
        let store = UserDetailStore(user: jon, gateway: gateway)

        store.dispatch(.toggleFollow)
        await waitUntil { store.state.message != nil }

        XCTAssertEqual(store.state.message, .followFailed(userId: jon.id, error: .storage(message: "disk full")))
        XCTAssertFalse(store.state.isFollowed)
        XCTAssertFalse(store.state.isTogglePending)
        store.dispatch(.messageShown)
        XCTAssertNil(store.state.message)
    }

    func testListAndDetailStayInSyncThroughTheSharedRepository() async {
        let gateway = FakeCoreGateway()
        gateway.immediateFetchResult = .success(FixtureUsers.all)
        gateway.immediateToggles = true
        let list = UserListStore(gateway: gateway)
        let detail = UserDetailStore(user: jon, gateway: gateway)
        await waitUntil { list.state.status == .content }

        detail.dispatch(.toggleFollow)
        await waitUntil { list.state.followedIds.contains(self.jon.id) }
        XCTAssertTrue(detail.state.isFollowed)

        list.dispatch(.toggleFollow(userId: jon.id))
        await waitUntil { !detail.state.isFollowed }
        XCTAssertFalse(list.state.followedIds.contains(jon.id))
    }

    func testFollowObservationIsDisposedWhenTheStoreIsReleased() async {
        let gateway = FakeCoreGateway()
        var store: UserDetailStore? = UserDetailStore(user: jon, gateway: gateway)
        XCTAssertEqual(gateway.activeObserverCount, 1)
        XCTAssertNotNil(store)

        store = nil

        await waitUntil { gateway.activeObserverCount == 0 }
    }
}
