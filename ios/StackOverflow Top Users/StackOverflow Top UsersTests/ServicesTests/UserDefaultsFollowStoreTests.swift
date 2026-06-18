import Testing
import Foundation
@testable import StackOverflow_Top_Users

struct UserDefaultsFollowStoreTests {
    private func makeStore() -> UserDefaultsFollowStore {
        let suite = "test." + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        return UserDefaultsFollowStore(defaults: defaults)
    }

    @Test func defaultNotFollowed() {
        #expect(makeStore().isFollowed(42) == false)
    }

    @Test func toggleOn() {
        let store = makeStore()
        store.setFollowed(true, for: 42)
        #expect(store.isFollowed(42) == true)
    }

    @Test func toggleOff() {
        let store = makeStore()
        store.setFollowed(true, for: 42)
        store.setFollowed(false, for: 42)
        #expect(store.isFollowed(42) == false)
    }

    @Test func perUserIndependence() {
        let store = makeStore()
        store.setFollowed(true, for: 1)
        #expect(store.isFollowed(1) == true)
        #expect(store.isFollowed(2) == false)
    }

    @Test func persistsAcrossInstances() {
        let suite = "test." + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        UserDefaultsFollowStore(defaults: defaults).setFollowed(true, for: 7)
        let reloaded = UserDefaultsFollowStore(defaults: defaults)
        #expect(reloaded.isFollowed(7) == true)
    }
}
