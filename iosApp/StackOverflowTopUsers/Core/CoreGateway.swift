import Foundation

// Swift-side view of the shared Kotlin core. Stores and views depend only on these types and on
// `CoreGateway`; the one file that imports the `Shared` framework is SharedCoreGateway.swift.
// That keeps Kotlin/Native interop naming in a single place and lets store tests run against
// a pure-Swift fake.

/// A Stack Overflow user, mirrored from the shared `User` entity. Dates are epoch seconds (UTC).
struct UserModel: Identifiable, Equatable, Hashable {
    let id: Int64
    let displayName: String
    let reputation: Int64
    let avatarUrl: String?
    let location: String?
    let websiteUrl: String?
    let creationDate: Int64
    let lastModifiedDate: Int64?
}

enum SortFieldModel: String, CaseIterable, Equatable {
    // Raw values match the Kotlin enum entry names; SharedCoreGateway maps by name.
    case reputation = "REPUTATION"
    case name = "NAME"
    case creation = "CREATION"
    case modified = "MODIFIED"

    var label: String {
        switch self {
        case .reputation: return "Reputation"
        case .name: return "Name"
        case .creation: return "Date created"
        case .modified: return "Date updated"
        }
    }
}

enum SortDirectionModel: String, CaseIterable, Equatable {
    case asc = "ASC"
    case desc = "DESC"

    var label: String {
        switch self {
        case .asc: return "Ascending"
        case .desc: return "Descending"
        }
    }
}

struct SortOptionModel: Equatable {
    var field: SortFieldModel
    var direction: SortDirectionModel

    /// Reputation, descending: the list's initial order (same as the core's `SortOption.Default`).
    static let `default` = SortOptionModel(field: .reputation, direction: .desc)
}

/// Mirror of the shared typed `CoreError`.
enum CoreErrorModel: Error, Equatable {
    /// Transport failure: offline, DNS, connection refused, timeout.
    case network(message: String?)
    /// Non-success HTTP status or StackExchange error object.
    case http(code: Int, apiMessage: String?)
    /// Response body could not be decoded.
    case decoding(message: String?)
    /// Local persistence failed or was corrupt.
    case storage(message: String?)

    var isStorage: Bool {
        if case .storage = self { return true }
        return false
    }
}

/// Handle for a follow-state observation. Cancels itself when released, so an owner that simply
/// drops its reference (e.g. a deallocated store) never leaks the underlying Kotlin coroutine.
final class FollowObservation: @unchecked Sendable {
    private let lock = NSLock()
    private var onCancel: (() -> Void)?

    init(onCancel: @escaping () -> Void) {
        self.onCancel = onCancel
    }

    var isCancelled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return onCancel == nil
    }

    func cancel() {
        lock.lock()
        let action = onCancel
        onCancel = nil
        lock.unlock()
        action?()
    }

    deinit {
        cancel()
    }
}

/// Everything the MVI stores need from the shared core. Main-actor isolated: stores live on the
/// main actor, and the real implementation calls into Kotlin from the main thread.
@MainActor
protocol CoreGateway: AnyObject {
    /// Non-nil if persisted follow state was unreadable at startup (it has been reset to empty).
    var startupStorageError: CoreErrorModel? { get }

    /// Current followed ids (snapshot).
    func followedIds() -> Set<Int64>

    /// Fetches the top users, sorted by `sort` in the core.
    func fetchTopUsers(sort: SortOptionModel) async -> Result<[UserModel], CoreErrorModel>

    /// Flips follow state; success carries the new state (true = followed).
    func toggleFollow(userId: Int64) async -> Result<Bool, CoreErrorModel>

    /// Client-side sort (the core's `SortUsers`: id tie-break, missing dates last).
    func sort(_ users: [UserModel], by option: SortOptionModel) -> [UserModel]

    /// Delivers the current followed ids, then every change, on the main actor until cancelled.
    func observeFollowedIds(_ onChange: @escaping @MainActor (Set<Int64>) -> Void) -> FollowObservation
}
