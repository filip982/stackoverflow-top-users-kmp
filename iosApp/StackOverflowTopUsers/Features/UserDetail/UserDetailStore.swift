import Foundation

struct UserDetailState: Equatable {
    let user: UserModel
    var isFollowed: Bool = false
    var isTogglePending: Bool = false
    var message: UserMessage?
}

enum UserDetailIntent: Equatable {
    case toggleFollow
    case messageShown
}

enum UserDetailMessage {
    case followedIdsChanged(Set<Int64>)
    case toggleStarted
    case toggleFinished(error: CoreErrorModel?)
    case messageShown
}

enum UserDetailReducer {
    static func reduce(_ state: UserDetailState, _ message: UserDetailMessage) -> UserDetailState {
        var next = state
        switch message {
        case let .followedIdsChanged(ids):
            next.isFollowed = ids.contains(state.user.id)
        case .toggleStarted:
            next.isTogglePending = true
        case let .toggleFinished(error):
            next.isTogglePending = false
            if let error {
                next.message = .followFailed(userId: state.user.id, error: error)
            }
        case .messageShown:
            next.message = nil
        }
        return next
    }
}

final class UserDetailStore: Store<UserDetailState, UserDetailIntent, UserDetailMessage, Never> {
    private let gateway: CoreGateway
    private var observation: FollowObservation?

    init(user: UserModel, gateway: CoreGateway) {
        self.gateway = gateway
        super.init(initial: UserDetailState(user: user, isFollowed: gateway.followedIds().contains(user.id)))
        // Follow state is never cached locally: it always mirrors the app-scoped repository.
        observation = gateway.observeFollowedIds { [weak self] ids in
            self?.apply(.followedIdsChanged(ids))
        }
    }

    deinit {
        observation?.cancel()
    }

    override func reduce(_ state: UserDetailState, _ message: UserDetailMessage) -> UserDetailState {
        UserDetailReducer.reduce(state, message)
    }

    override func dispatch(_ intent: UserDetailIntent) {
        switch intent {
        case .toggleFollow:
            guard !state.isTogglePending else { return } // rapid-toggle policy: drop taps while in flight
            apply(.toggleStarted)
            let userId = state.user.id
            let gateway = self.gateway
            Task { [weak self] in
                let result = await gateway.toggleFollow(userId: userId)
                guard let self else { return }
                switch result {
                case .success:
                    self.apply(.toggleFinished(error: nil))
                case let .failure(error):
                    self.apply(.toggleFinished(error: error))
                }
            }
        case .messageShown:
            apply(.messageShown)
        }
    }
}
