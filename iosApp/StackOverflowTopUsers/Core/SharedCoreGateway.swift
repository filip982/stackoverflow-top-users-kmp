import Foundation
import Shared

// The ONLY file that imports the Kotlin `Shared` framework. Every Kotlin/Native → Objective-C →
// Swift naming assumption lives here, so an interop surprise is a one-file fix:
//
// - Top-level Kotlin functions are members of a `<File>Kt` class; `HttpClientFactory.ios.kt` → `HttpClientFactory_iosKt`.
// - Kotlin default arguments are not exported: every constructor/function argument is passed explicitly.
// - Kotlin `Long` → `Int64`; `Long?` and `Long` inside collections → `KotlinLong` (an NSNumber subclass).
// - Generic `Outcome<List<User>>` → `Outcome<NSArray>`. We use its `getOrNull()` / `errorOrNull()` members
//   rather than casting to the nested `Outcome.Success` / `Outcome.Failure` subclasses.
// - Nested classes of a non-generic class stay nested in Swift: `CoreError.Http`, `CoreError.Network`, ...
//   (ObjC name `SharedCoreErrorHttp`). Nested classes of the generic `Outcome` are flattened
//   (`OutcomeSuccess`, `OutcomeFailure`) because Swift cannot nest types in imported ObjC generics.
// - `suspend fun` → completion-handler method (`invoke(option:completionHandler:)`); we call that variant
//   explicitly from the main actor and bridge with a continuation, so the Kotlin call always starts on
//   the main thread (the Gradle config also lifts that restriction as a second line of defence).
// - Kotlin enums: looked up by `name` via `values()` instead of relying on exported entry spellings.
// - `fun interface Cancellable` → ObjC protocol; held as an opaque value and only `cancel()`-ed.

/// Production `CoreGateway`: one per process, owning the single app-scoped `StackOverflowCore`.
@MainActor
final class SharedCoreGateway: CoreGateway {
    /// Key the shared `SettingsFollowStore` uses inside the injected `UserDefaults`.
    nonisolated static let followStorageKey = "followed_user_ids"
    nonisolated static let requestTimeoutMillis: Int64 = 15_000

    private let core: StackOverflowCore
    private let defaults: UserDefaults

    init(baseUrl: String, defaults: UserDefaults) {
        self.defaults = defaults
        let settings = NSUserDefaultsSettings(delegate: defaults)
        let httpClient = HttpClientFactory_iosKt.createPlatformHttpClient(requestTimeoutMillis: Self.requestTimeoutMillis)
        self.core = StackOverflowCore(baseUrl: baseUrl, settings: settings, httpClient: httpClient)
    }

    var startupStorageError: CoreErrorModel? {
        core.repository.startupStorageError.map { SharedMapping.errorModel($0) }
    }

    func followedIds() -> Set<Int64> {
        SharedMapping.ids(core.repository.followedIds())
    }

    func fetchTopUsers(sort: SortOptionModel) async -> Result<[UserModel], CoreErrorModel> {
        let option = SharedMapping.sharedSortOption(sort)
        let getTopUsers = core.getTopUsers
        return await withCheckedContinuation { (continuation: CheckedContinuation<Result<[UserModel], CoreErrorModel>, Never>) in
            getTopUsers.invoke(option: option) { outcome, error in
                // Map on the calling (Kotlin) thread; only Swift value types cross back to the main actor.
                let result: Result<[UserModel], CoreErrorModel>
                if let error {
                    result = .failure(.network(message: error.localizedDescription))
                } else if let outcome {
                    result = SharedMapping.usersResult(value: outcome.getOrNull(), error: outcome.errorOrNull())
                } else {
                    result = .failure(.network(message: "No result from the shared core"))
                }
                continuation.resume(returning: result)
            }
        }
    }

    func toggleFollow(userId: Int64) async -> Result<Bool, CoreErrorModel> {
        let toggle = core.toggleFollow
        let result = await withCheckedContinuation { (continuation: CheckedContinuation<Result<Bool, CoreErrorModel>, Never>) in
            toggle.invoke(userId: userId) { outcome, error in
                let result: Result<Bool, CoreErrorModel>
                if let error {
                    result = .failure(.storage(message: error.localizedDescription))
                } else if let outcome {
                    result = SharedMapping.boolResult(value: outcome.getOrNull(), error: outcome.errorOrNull())
                } else {
                    result = .failure(.storage(message: "No result from the shared core"))
                }
                continuation.resume(returning: result)
            }
        }
        if case .success = result {
            // The core persisted synchronously into these defaults; flush so an immediate process
            // kill (XCUITest `terminate()`, crash) cannot lose the change.
            defaults.synchronize()
        }
        return result
    }

    func sort(_ users: [UserModel], by option: SortOptionModel) -> [UserModel] {
        let sorted = core.sortUsers.invoke(users: users.map(SharedMapping.sharedUser), option: SharedMapping.sharedSortOption(option))
        return sorted.map(SharedMapping.userModel)
    }

    func observeFollowedIds(_ onChange: @escaping @MainActor (Set<Int64>) -> Void) -> FollowObservation {
        // The repository invokes the callback on a Kotlin background dispatcher: convert there, then
        // hop to the main queue. DispatchQueue (not Task) keeps delivery strictly FIFO, so a stale
        // snapshot can never overtake a newer one.
        let handle = core.repository.watchFollowedIds { ids in
            let snapshot = SharedMapping.ids(ids)
            DispatchQueue.main.async {
                MainActor.assumeIsolated { onChange(snapshot) }
            }
        }
        return FollowObservation { handle.cancel() }
    }
}

/// Pure conversions between Shared (Kotlin) types and the Swift models.
enum SharedMapping {
    static func userModel(_ user: User) -> UserModel {
        UserModel(
            id: user.id,
            displayName: user.displayName,
            reputation: user.reputation,
            avatarUrl: user.avatarUrl,
            location: user.location,
            websiteUrl: user.websiteUrl,
            creationDate: user.creationDate,
            lastModifiedDate: user.lastModifiedDate?.int64Value
        )
    }

    static func sharedUser(_ model: UserModel) -> User {
        User(
            id: model.id,
            displayName: model.displayName,
            reputation: model.reputation,
            avatarUrl: model.avatarUrl,
            location: model.location,
            websiteUrl: model.websiteUrl,
            creationDate: model.creationDate,
            lastModifiedDate: model.lastModifiedDate.map { KotlinLong(longLong: $0) }
        )
    }

    static func ids(_ ids: Set<KotlinLong>) -> Set<Int64> {
        Set(ids.map { $0.int64Value })
    }

    static func errorModel(_ error: CoreError) -> CoreErrorModel {
        if let http = error as? CoreError.Http {
            return .http(code: Int(http.code), apiMessage: http.apiMessage)
        }
        if error is CoreError.Decoding {
            return .decoding(message: error.message)
        }
        if error is CoreError.Storage {
            return .storage(message: error.message)
        }
        // CoreError.Network, and anything a future core version adds.
        return .network(message: error.message)
    }

    /// `value` / `error` are an `Outcome`'s `getOrNull()` / `errorOrNull()`.
    static func usersResult(value: Any?, error: CoreError?) -> Result<[UserModel], CoreErrorModel> {
        if let error {
            return .failure(errorModel(error))
        }
        guard let users = value as? [User] else {
            return .failure(.decoding(message: "Unexpected success payload from the shared core"))
        }
        return .success(users.map(userModel))
    }

    static func boolResult(value: KotlinBoolean?, error: CoreError?) -> Result<Bool, CoreErrorModel> {
        if let error {
            return .failure(errorModel(error))
        }
        guard let value else {
            return .failure(.storage(message: "Unexpected success payload from the shared core"))
        }
        return .success(value.boolValue)
    }

    static func sharedSortOption(_ option: SortOptionModel) -> SortOption {
        SortOption(field: sharedField(option.field), direction: sharedDirection(option.direction))
    }

    static func sharedField(_ field: SortFieldModel) -> SortField {
        let all = SortField.values()
        for index in 0..<all.size {
            if let entry = all.get(index: index), entry.name == field.rawValue {
                return entry
            }
        }
        preconditionFailure("Shared SortField has no entry named \(field.rawValue)")
    }

    static func sharedDirection(_ direction: SortDirectionModel) -> SortDirection {
        let all = SortDirection.values()
        for index in 0..<all.size {
            if let entry = all.get(index: index), entry.name == direction.rawValue {
                return entry
            }
        }
        preconditionFailure("Shared SortDirection has no entry named \(direction.rawValue)")
    }
}

#if DEBUG
/// Debug-only hooks that let the unit-test bundle exercise real Shared types without importing the
/// static `Shared` framework itself (linking it into the test bundle too would duplicate the Kotlin
/// runtime). Signatures use Swift types only.
enum SharedContractProbe {
    static var coreProductionBaseUrl: String {
        StackOverflowCore.companion.PRODUCTION_BASE_URL
    }

    /// Swift model → Shared `User` (incl. `KotlinLong?` boxing) → Swift model.
    static func roundTrip(_ user: UserModel) -> UserModel {
        SharedMapping.userModel(SharedMapping.sharedUser(user))
    }

    /// Wraps `users` in a real `Outcome.Success` and maps it back through the production path.
    static func mapSuccess(_ users: [UserModel]) -> Result<[UserModel], CoreErrorModel> {
        let shared = users.map(SharedMapping.sharedUser)
        let outcome = OutcomeSuccess<NSArray>(value: shared as NSArray)
        return SharedMapping.usersResult(value: outcome.getOrNull(), error: outcome.errorOrNull())
    }

    enum ErrorKind {
        case network, http(code: Int32, apiMessage: String?), decoding, storage
    }

    /// Wraps a real `CoreError` subclass in `Outcome.Failure` and maps it through the production path.
    static func mapFailure(_ kind: ErrorKind) -> Result<[UserModel], CoreErrorModel> {
        let error: CoreError
        switch kind {
        case .network: error = CoreError.Network(cause: nil)
        case let .http(code, apiMessage): error = CoreError.Http(code: code, apiMessage: apiMessage)
        case .decoding: error = CoreError.Decoding(cause: nil)
        case .storage: error = CoreError.Storage(cause: nil)
        }
        let outcome = OutcomeFailure(error: error)
        return SharedMapping.usersResult(value: outcome.getOrNull(), error: outcome.errorOrNull())
    }

    /// Kotlin enum names round-trip for every Swift sort case.
    static func sharedSortNames(_ option: SortOptionModel) -> (field: String, direction: String) {
        let shared = SharedMapping.sharedSortOption(option)
        return (shared.field.name, shared.direction.name)
    }
}
#endif
