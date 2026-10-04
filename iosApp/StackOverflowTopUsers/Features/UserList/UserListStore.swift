import Foundation

enum ListStatus: Equatable {
    case loading
    case content
    /// The request succeeded but returned no users — distinct from `failed`.
    case empty
    case failed(CoreErrorModel)
}

struct UserListState: Equatable {
    var status: ListStatus = .loading
    var users: [UserModel] = []
    var followedIds: Set<Int64> = []
    /// Users with a follow toggle in flight; further taps on them are dropped (rapid-toggle policy).
    var pendingFollowIds: Set<Int64> = []
    var sort: SortOptionModel = .default
    var message: UserMessage?
    /// Id of the only fetch whose completion may still change state (latest request wins).
    var activeRequestId: Int = 0
}

enum UserListIntent: Equatable {
    case retry
    case toggleFollow(userId: Int64)
    case applySort(SortOptionModel)
    case messageShown
}

/// Reducer inputs: results of intents and effects.
enum UserListMessage {
    case loadStarted(requestId: Int)
    case loadFinished(requestId: Int, result: Result<[UserModel], CoreErrorModel>)
    case followedIdsChanged(Set<Int64>)
    case toggleStarted(userId: Int64)
    case toggleFinished(userId: Int64, error: CoreErrorModel?)
    case sortApplied(option: SortOptionModel, sortedUsers: [UserModel])
    case startupStorageError(CoreErrorModel)
    case messageShown
}

enum UserListReducer {
    /// Pure list reducer (same transitions as androidApp's `reduceUserList`).
    static func reduce(_ state: UserListState, _ message: UserListMessage) -> UserListState {
        var next = state
        switch message {
        case let .loadStarted(requestId):
            next.status = .loading
            next.users = []
            next.activeRequestId = requestId
        case let .loadFinished(requestId, result):
            // Stale completion: a newer request owns the screen.
            guard requestId == state.activeRequestId else { return state }
            switch result {
            case let .success(users):
                next.status = users.isEmpty ? .empty : .content
                next.users = users
            case let .failure(error):
                next.status = .failed(error)
                next.users = []
            }
        case let .followedIdsChanged(ids):
            next.followedIds = ids
        case let .toggleStarted(userId):
            next.pendingFollowIds.insert(userId)
        case let .toggleFinished(userId, error):
            next.pendingFollowIds.remove(userId)
            if let error {
                next.message = .followFailed(userId: userId, error: error)
            }
        case let .sortApplied(option, sortedUsers):
            next.sort = option
            next.users = sortedUsers
        case let .startupStorageError(error):
            if next.message == nil {
                next.message = .followStateReset(error)
            }
        case .messageShown:
            next.message = nil
        }
        return next
    }
}

/// Thin list store: fetching, sorting and follow mutation are delegated to the shared core via
/// `CoreGateway`; follow state is observed from the single app-scoped repository so list and detail
/// stay in sync.
final class UserListStore: Store<UserListState, UserListIntent, UserListMessage, Never> {
    private let gateway: CoreGateway
    private var observation: FollowObservation?
    private var loadTask: Task<Void, Never>?
    private var lastRequestId = 0

    init(gateway: CoreGateway, startupStorageError: CoreErrorModel? = nil) {
        self.gateway = gateway
        super.init(initial: UserListState(followedIds: gateway.followedIds()))
        if let startupStorageError {
            apply(.startupStorageError(startupStorageError))
        }
        observation = gateway.observeFollowedIds { [weak self] ids in
            self?.apply(.followedIdsChanged(ids))
        }
        load()
    }

    deinit {
        observation?.cancel()
        loadTask?.cancel()
    }

    override func reduce(_ state: UserListState, _ message: UserListMessage) -> UserListState {
        UserListReducer.reduce(state, message)
    }

    override func dispatch(_ intent: UserListIntent) {
        switch intent {
        case .retry:
            load()
        case let .toggleFollow(userId):
            toggle(userId)
        case let .applySort(option):
            apply(.sortApplied(option: option, sortedUsers: gateway.sort(state.users, by: option)))
        case .messageShown:
            apply(.messageShown)
        }
    }

    /// Latest request wins: the previous fetch is cancelled and its completion, if any, is ignored by id.
    private func load() {
        lastRequestId += 1
        let requestId = lastRequestId
        loadTask?.cancel()
        apply(.loadStarted(requestId: requestId))
        let requestedSort = state.sort
        let gateway = self.gateway
        loadTask = Task { [weak self] in
            let result = await gateway.fetchTopUsers(sort: requestedSort)
            guard let self else { return }
            // A sort applied while the request was in flight still wins.
            let current = self.state.sort
            let adjusted: Result<[UserModel], CoreErrorModel>
            switch result {
            case let .success(users):
                adjusted = .success(current == requestedSort ? users : gateway.sort(users, by: current))
            case .failure:
                adjusted = result
            }
            self.apply(.loadFinished(requestId: requestId, result: adjusted))
        }
    }

    /// Rapid-toggle policy: one in-flight toggle per user; taps on that user meanwhile are dropped.
    private func toggle(_ userId: Int64) {
        guard !state.pendingFollowIds.contains(userId) else { return }
        apply(.toggleStarted(userId: userId))
        let gateway = self.gateway
        Task { [weak self] in
            let result = await gateway.toggleFollow(userId: userId)
            guard let self else { return }
            switch result {
            case .success:
                self.apply(.toggleFinished(userId: userId, error: nil))
            case let .failure(error):
                self.apply(.toggleFinished(userId: userId, error: error))
            }
        }
    }
}
