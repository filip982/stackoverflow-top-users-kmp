import Foundation

/// `committed` is what the list currently uses; edits only touch `draft` until Apply.
struct SortOptionsState: Equatable {
    var committed: SortOptionModel
    var draft: SortOptionModel

    init(committed: SortOptionModel) {
        self.committed = committed
        self.draft = committed
    }
}

enum SortOptionsIntent: Equatable {
    case selectField(SortFieldModel)
    case selectDirection(SortDirectionModel)
    case apply
    case cancel
}

enum SortOptionsEffect: Equatable {
    case applied(SortOptionModel)
    case dismissed
}

enum SortOptionsReducer {
    static func reduce(_ state: SortOptionsState, _ intent: SortOptionsIntent) -> SortOptionsState {
        var next = state
        switch intent {
        case let .selectField(field):
            next.draft.field = field
        case let .selectDirection(direction):
            next.draft.direction = direction
        case .apply:
            next.committed = state.draft
        case .cancel:
            next.draft = state.committed
        }
        return next
    }
}

/// Synchronous store: intents are their own reducer messages; Apply/Cancel emit one-shot effects.
final class SortOptionsStore: Store<SortOptionsState, SortOptionsIntent, SortOptionsIntent, SortOptionsEffect> {
    init(initial: SortOptionModel) {
        super.init(initial: SortOptionsState(committed: initial))
    }

    override func reduce(_ state: SortOptionsState, _ message: SortOptionsIntent) -> SortOptionsState {
        SortOptionsReducer.reduce(state, message)
    }

    override func dispatch(_ intent: SortOptionsIntent) {
        apply(intent)
        switch intent {
        case .apply:
            emit(.applied(state.committed))
        case .cancel:
            emit(.dismissed)
        case .selectField, .selectDirection:
            break
        }
    }
}
