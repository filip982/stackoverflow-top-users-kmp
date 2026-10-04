import Foundation
import XCTest
@testable import StackOverflowTopUsers

/// Controllable in-memory `CoreGateway` for store tests (no Shared framework involved).
///
/// - Fetches and toggles are deferred by default: the test decides when and how each completes,
///   which is how stale-completion and rapid-toggle behaviour is driven deterministically.
/// - Follow state behaves like the shared repository: a successful toggle updates the set and
///   notifies every observer (so list/detail sync can be tested).
@MainActor
final class FakeCoreGateway: CoreGateway {
    typealias UsersResult = Result<[UserModel], CoreErrorModel>

    var startupStorageError: CoreErrorModel?

    /// When set, fetches complete immediately with this result (sorted like the core would).
    var immediateFetchResult: UsersResult?
    /// When true, toggles complete immediately (succeeding unless `toggleError` is set).
    var immediateToggles = false
    var toggleError: CoreErrorModel?

    private(set) var fetchRequests: [SortOptionModel] = []
    private(set) var toggleRequests: [Int64] = []
    private(set) var sortCalls = 0

    private var followed: Set<Int64>
    private var pendingFetches: [Int: CheckedContinuation<UsersResult, Never>] = [:]
    private var pendingToggles: [Int: (userId: Int64, continuation: CheckedContinuation<Result<Bool, CoreErrorModel>, Never>)] = [:]
    private var observers: [UUID: @MainActor (Set<Int64>) -> Void] = [:]

    init(followed: Set<Int64> = []) {
        self.followed = followed
    }

    var activeObserverCount: Int { observers.count }
    var pendingFetchCount: Int { pendingFetches.count }
    var pendingToggleCount: Int { pendingToggles.count }

    func hasPendingFetch(_ index: Int) -> Bool { pendingFetches[index] != nil }
    func hasPendingToggle(_ index: Int) -> Bool { pendingToggles[index] != nil }

    // MARK: CoreGateway

    func followedIds() -> Set<Int64> { followed }

    func fetchTopUsers(sort: SortOptionModel) async -> UsersResult {
        fetchRequests.append(sort)
        let index = fetchRequests.count - 1
        if let immediate = immediateFetchResult {
            return immediate.map { ReferenceSort.sorted($0, by: sort) }
        }
        return await withCheckedContinuation { continuation in
            pendingFetches[index] = continuation
        }
    }

    func toggleFollow(userId: Int64) async -> Result<Bool, CoreErrorModel> {
        toggleRequests.append(userId)
        let index = toggleRequests.count - 1
        if immediateToggles {
            return performToggle(userId)
        }
        return await withCheckedContinuation { continuation in
            pendingToggles[index] = (userId, continuation)
        }
    }

    func sort(_ users: [UserModel], by option: SortOptionModel) -> [UserModel] {
        sortCalls += 1
        return ReferenceSort.sorted(users, by: option)
    }

    func observeFollowedIds(_ onChange: @escaping @MainActor (Set<Int64>) -> Void) -> FollowObservation {
        let id = UUID()
        observers[id] = onChange
        onChange(followed) // like the repository: current value first
        return FollowObservation { [weak self] in
            // Tokens are normally released on main (store deinit); hop only if they are not.
            if Thread.isMainThread {
                MainActor.assumeIsolated { self?.removeObserver(id) }
            } else {
                Task { @MainActor in self?.removeObserver(id) }
            }
        }
    }

    // MARK: Test controls

    /// Completes the `index`-th fetch (0-based, in request order) with `result`, sorted by the sort
    /// that request asked for, like the core's GetTopUsers.
    func completeFetch(_ index: Int, with result: UsersResult) {
        guard let continuation = pendingFetches.removeValue(forKey: index) else {
            XCTFail("No pending fetch #\(index); requests so far: \(fetchRequests.count)")
            return
        }
        let sortForRequest = fetchRequests[index]
        continuation.resume(returning: result.map { ReferenceSort.sorted($0, by: sortForRequest) })
    }

    /// Completes the `index`-th toggle (0-based, in request order).
    func completeToggle(_ index: Int) {
        guard let pending = pendingToggles.removeValue(forKey: index) else {
            XCTFail("No pending toggle #\(index); requests so far: \(toggleRequests.count)")
            return
        }
        pending.continuation.resume(returning: performToggle(pending.userId))
    }

    /// Simulates a follow change made elsewhere in the app (e.g. on another screen).
    func externalFollowChange(_ ids: Set<Int64>) {
        followed = ids
        notify()
    }

    /// Resumes anything still pending so no continuation leaks past a test.
    func drainPending() {
        for (_, continuation) in pendingFetches {
            continuation.resume(returning: .failure(.network(message: "test finished")))
        }
        pendingFetches.removeAll()
        for (_, pending) in pendingToggles {
            pending.continuation.resume(returning: .failure(.storage(message: "test finished")))
        }
        pendingToggles.removeAll()
    }

    private func performToggle(_ userId: Int64) -> Result<Bool, CoreErrorModel> {
        if let toggleError {
            return .failure(toggleError)
        }
        let nowFollowing = !followed.contains(userId)
        if nowFollowing {
            followed.insert(userId)
        } else {
            followed.remove(userId)
        }
        notify()
        return .success(nowFollowing)
    }

    private func removeObserver(_ id: UUID) {
        observers[id] = nil
    }

    private func notify() {
        for observer in observers.values {
            observer(followed)
        }
    }
}

/// Swift reference of the core's SortUsers contract (id tie-break, missing dates last) used by the
/// fake. The real implementation is exercised in SharedContractTests.
enum ReferenceSort {
    static func sorted(_ users: [UserModel], by option: SortOptionModel) -> [UserModel] {
        users.sorted { a, b in
            let order = compare(a, b, option)
            return order == .orderedSame ? a.id < b.id : order == .orderedAscending
        }
    }

    private static func compare(_ a: UserModel, _ b: UserModel, _ option: SortOptionModel) -> ComparisonResult {
        let raw: ComparisonResult
        switch option.field {
        case .reputation:
            raw = compareValues(a.reputation, b.reputation)
        case .name:
            raw = compareValues(a.displayName.lowercased(), b.displayName.lowercased())
        case .creation:
            raw = compareValues(a.creationDate, b.creationDate)
        case .modified:
            switch (a.lastModifiedDate, b.lastModifiedDate) {
            case (nil, nil): return .orderedSame
            case (nil, _): return .orderedDescending // missing last, in either direction
            case (_, nil): return .orderedAscending
            case let (x?, y?): raw = compareValues(x, y)
            }
        }
        guard option.direction == .desc else { return raw }
        switch raw {
        case .orderedAscending: return .orderedDescending
        case .orderedDescending: return .orderedAscending
        case .orderedSame: return .orderedSame
        }
    }

    private static func compareValues<T: Comparable>(_ x: T, _ y: T) -> ComparisonResult {
        x < y ? .orderedAscending : (x > y ? .orderedDescending : .orderedSame)
    }
}
