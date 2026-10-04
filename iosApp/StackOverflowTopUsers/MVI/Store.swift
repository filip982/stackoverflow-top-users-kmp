import Foundation
import Combine

/// Minimal hand-rolled MVI store, mirroring androidApp's `mvi/Store.kt`:
/// `dispatch(intent)` → side effects (async, in the store) → messages → pure `reduce(state, message)`
/// → published `state`. One-shot outputs (navigation) go through `onEffect`.
///
/// Main-actor isolated: state is only ever mutated on the main thread, and async effects started
/// from `dispatch` inherit main-actor isolation, so their completions apply in order on main.
@MainActor
class Store<State: Equatable, Intent, Message, Effect>: ObservableObject {
    @Published private(set) var state: State

    /// Receives one-shot effects (e.g. "sort applied"). Set by the view layer or a test.
    var onEffect: (@MainActor (Effect) -> Void)?

    init(initial: State) {
        self.state = initial
    }

    /// Entry point for the view. Subclasses override.
    func dispatch(_ intent: Intent) {
        preconditionFailure("\(type(of: self)) must override dispatch(_:)")
    }

    /// Pure state transition. Subclasses override by delegating to a static pure reducer.
    func reduce(_ state: State, _ message: Message) -> State {
        preconditionFailure("\(type(of: self)) must override reduce(_:_:)")
    }

    final func apply(_ message: Message) {
        let next = reduce(state, message)
        if next != state {
            state = next
        }
    }

    final func emit(_ effect: Effect) {
        onEffect?(effect)
    }
}

/// Transient, show-once notices carried in screen state and cleared by a `messageShown` intent.
enum UserMessage: Equatable {
    case followFailed(userId: Int64, error: CoreErrorModel)
    /// Persisted follow state was unreadable at startup and has been reset.
    case followStateReset(CoreErrorModel)
}
