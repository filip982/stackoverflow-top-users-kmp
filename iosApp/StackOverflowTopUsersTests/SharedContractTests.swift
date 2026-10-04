import XCTest
@testable import StackOverflowTopUsers

/// Swift ↔ Kotlin contract (plan §9.11): exercises the REAL `Shared` framework through the app's
/// interop layer — entity construction, `KotlinLong?` boxing, `Outcome` success/failure mapping,
/// typed `CoreError` subclasses, Kotlin enums, `SortUsers`, suspend bridging, follow persistence
/// in NSUserDefaults, fresh-instance reload, observation delivery/disposal, corrupt-storage reset.
///
/// The test bundle never imports `Shared` itself (the static framework is linked into the host app
/// only); `SharedContractProbe` and `SharedCoreGateway` are the bridge.
@MainActor
final class SharedContractTests: XCTestCase {
    /// Nothing listens on the discard port: connection refused → typed network error, no internet needed.
    private let unreachableBaseUrl = "http://localhost:9"

    private func makeSuite() -> (UserDefaults, String) {
        let suiteName = "contract-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        addTeardownBlock {
            UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName)
        }
        return (defaults, suiteName)
    }

    // MARK: Pure type mapping

    func testProductionBaseUrlMatchesTheCoreConstant() {
        XCTAssertEqual(SharedContractProbe.coreProductionBaseUrl, AppConfiguration.productionBaseUrl)
    }

    func testUserRoundTripsThroughTheSharedEntity() {
        let full = FixtureUsers.jon
        let sparse = UserModel(
            id: Int64.max, displayName: "Ren\u{e9} \"Ren\" Gentle", reputation: 0,
            avatarUrl: nil, location: nil, websiteUrl: nil,
            creationDate: 0, lastModifiedDate: nil
        )

        XCTAssertEqual(SharedContractProbe.roundTrip(full), full)
        XCTAssertEqual(SharedContractProbe.roundTrip(sparse), sparse, "nil optionals and Int64 extremes survive")
    }

    func testSuccessOutcomeMapsToUsers() {
        let users = [FixtureUsers.jon, FixtureUsers.alex]

        XCTAssertEqual(SharedContractProbe.mapSuccess(users), .success(users))
        XCTAssertEqual(SharedContractProbe.mapSuccess([]), .success([]))
    }

    func testEachCoreErrorSubclassMapsToItsTypedModel() {
        XCTAssertEqual(
            SharedContractProbe.mapFailure(.http(code: 400, apiMessage: "throttle violation")),
            .failure(.http(code: 400, apiMessage: "throttle violation"))
        )
        XCTAssertEqual(SharedContractProbe.mapFailure(.http(code: 503, apiMessage: nil)), .failure(.http(code: 503, apiMessage: nil)))

        guard case .failure(.network) = SharedContractProbe.mapFailure(.network) else {
            return XCTFail("CoreError.Network should map to .network")
        }
        guard case .failure(.decoding) = SharedContractProbe.mapFailure(.decoding) else {
            return XCTFail("CoreError.Decoding should map to .decoding")
        }
        guard case .failure(.storage) = SharedContractProbe.mapFailure(.storage) else {
            return XCTFail("CoreError.Storage should map to .storage")
        }
    }

    func testEverySwiftSortCaseHasAKotlinEnumCounterpart() {
        for field in SortFieldModel.allCases {
            for direction in SortDirectionModel.allCases {
                let names = SharedContractProbe.sharedSortNames(SortOptionModel(field: field, direction: direction))
                XCTAssertEqual(names.field, field.rawValue)
                XCTAssertEqual(names.direction, direction.rawValue)
            }
        }
    }

    // MARK: Real core through SharedCoreGateway

    func testSharedSortUsersBreaksTiesByIdAndPutsMissingDatesLast() {
        let (defaults, _) = makeSuite()
        let gateway = SharedCoreGateway(baseUrl: unreachableBaseUrl, defaults: defaults)
        let users = FixtureUsers.all

        XCTAssertEqual(
            gateway.sort(users, by: SortOptionModel(field: .reputation, direction: .desc)).map(\.id),
            FixtureUsers.byReputationDesc.map(\.id)
        )
        XCTAssertEqual(
            gateway.sort(users, by: SortOptionModel(field: .name, direction: .asc)).map(\.id),
            FixtureUsers.byNameAsc.map(\.id)
        )
        // Alex has no last-modified date: last in BOTH directions.
        XCTAssertEqual(gateway.sort(users, by: SortOptionModel(field: .modified, direction: .asc)).last, FixtureUsers.alex)
        XCTAssertEqual(gateway.sort(users, by: SortOptionModel(field: .modified, direction: .desc)).last, FixtureUsers.alex)

        let twinA = UserModel(id: 2, displayName: "Twin", reputation: 10, avatarUrl: nil, location: nil,
                              websiteUrl: nil, creationDate: 1, lastModifiedDate: nil)
        let twinB = UserModel(id: 1, displayName: "Twin", reputation: 10, avatarUrl: nil, location: nil,
                              websiteUrl: nil, creationDate: 1, lastModifiedDate: nil)
        XCTAssertEqual(
            gateway.sort([twinA, twinB], by: SortOptionModel(field: .reputation, direction: .desc)).map(\.id),
            [1, 2],
            "ties break on id ascending"
        )
    }

    func testUnreachableServerYieldsATypedNetworkErrorThroughTheSuspendBridge() async {
        let (defaults, _) = makeSuite()
        let gateway = SharedCoreGateway(baseUrl: unreachableBaseUrl, defaults: defaults)

        let result = await gateway.fetchTopUsers(sort: .default)

        guard case .failure(.network) = result else {
            return XCTFail("expected .network failure, got \(result)")
        }
    }

    func testToggleFollowPersistsAndAFreshCoreReloadsIt() async {
        let (defaults, suiteName) = makeSuite()
        let gateway = SharedCoreGateway(baseUrl: unreachableBaseUrl, defaults: defaults)
        XCTAssertNil(gateway.startupStorageError)
        XCTAssertEqual(gateway.followedIds(), [])

        let followed = await gateway.toggleFollow(userId: FixtureUsers.jon.id)
        XCTAssertEqual(followed, .success(true))
        XCTAssertEqual(gateway.followedIds(), [FixtureUsers.jon.id])
        XCTAssertNotNil(defaults.string(forKey: SharedCoreGateway.followStorageKey), "persisted in NSUserDefaults")

        // A second core over the same storage = what a relaunch sees.
        let relaunched = SharedCoreGateway(baseUrl: unreachableBaseUrl, defaults: UserDefaults(suiteName: suiteName)!)
        XCTAssertEqual(relaunched.followedIds(), [FixtureUsers.jon.id])

        let unfollowed = await relaunched.toggleFollow(userId: FixtureUsers.jon.id)
        XCTAssertEqual(unfollowed, .success(false))
        XCTAssertEqual(relaunched.followedIds(), [])
    }

    func testObservationDeliversOnTheMainThreadAndStopsAfterCancel() async {
        let (defaults, _) = makeSuite()
        let gateway = SharedCoreGateway(baseUrl: unreachableBaseUrl, defaults: defaults)
        var deliveries: [Set<Int64>] = []
        var allOnMain = true

        let observation = gateway.observeFollowedIds { ids in
            allOnMain = allOnMain && Thread.isMainThread
            deliveries.append(ids)
        }
        await waitUntil(timeout: 5, "initial value") { deliveries == [[]] }

        _ = await gateway.toggleFollow(userId: FixtureUsers.alex.id)
        await waitUntil(timeout: 5, "change delivered") { deliveries.last == [FixtureUsers.alex.id] }

        observation.cancel()
        XCTAssertTrue(observation.isCancelled)
        let countAfterCancel = deliveries.count
        _ = await gateway.toggleFollow(userId: FixtureUsers.alex.id)
        try? await Task.sleep(nanoseconds: 300_000_000)
        await settle()

        XCTAssertEqual(deliveries.count, countAfterCancel, "no deliveries after cancel")
        XCTAssertTrue(allOnMain, "every delivery happened on the main thread")
    }

    func testCorruptPersistedFollowStateIsResetAndSurfaced() {
        let (defaults, _) = makeSuite()
        defaults.set("22656,not-a-number", forKey: SharedCoreGateway.followStorageKey)

        let gateway = SharedCoreGateway(baseUrl: unreachableBaseUrl, defaults: defaults)

        XCTAssertEqual(gateway.startupStorageError?.isStorage, true)
        XCTAssertEqual(gateway.followedIds(), [])
    }
}
