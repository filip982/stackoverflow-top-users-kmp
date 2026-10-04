import XCTest
@testable import StackOverflowTopUsers

/// Mirrors androidApp's SortOptionsStoreTest: Apply/Cancel draft semantics (plan §9.7).
@MainActor
final class SortOptionsStoreTests: XCTestCase {
    private func makeStore(_ initial: SortOptionModel = .default) -> (SortOptionsStore, EffectRecorder) {
        let store = SortOptionsStore(initial: initial)
        let recorder = EffectRecorder()
        store.onEffect = { recorder.effects.append($0) }
        return (store, recorder)
    }

    func testDefaultsToReputationDescendingWithDraftEqualToCommitted() {
        let (store, _) = makeStore()

        XCTAssertEqual(store.state.committed, SortOptionModel(field: .reputation, direction: .desc))
        XCTAssertEqual(store.state.draft, store.state.committed)
    }

    func testEditsChangeOnlyTheDraft() {
        let (store, recorder) = makeStore()

        store.dispatch(.selectField(.name))
        store.dispatch(.selectDirection(.asc))

        XCTAssertEqual(store.state.draft, SortOptionModel(field: .name, direction: .asc))
        XCTAssertEqual(store.state.committed, .default)
        XCTAssertTrue(recorder.effects.isEmpty)
    }

    func testCancelDiscardsTheDraftAndNeverApplies() {
        let (store, recorder) = makeStore()

        store.dispatch(.selectField(.modified))
        store.dispatch(.cancel)

        XCTAssertEqual(store.state.draft, .default)
        XCTAssertEqual(store.state.committed, .default)
        XCTAssertEqual(recorder.effects, [.dismissed])
    }

    func testApplyCommitsTheDraftAndEmitsIt() {
        let (store, recorder) = makeStore()

        store.dispatch(.selectField(.creation))
        store.dispatch(.selectDirection(.asc))
        store.dispatch(.apply)

        let expected = SortOptionModel(field: .creation, direction: .asc)
        XCTAssertEqual(store.state.committed, expected)
        XCTAssertEqual(recorder.effects, [.applied(expected)])
    }

    func testStartsFromTheListsCurrentSort() {
        let current = SortOptionModel(field: .name, direction: .asc)
        let (store, _) = makeStore(current)

        XCTAssertEqual(store.state.committed, current)
        XCTAssertEqual(store.state.draft, current)
    }

    func testReducerResetsTheDraftToCommittedOnCancel() {
        var state = SortOptionsState(committed: .default)
        state.draft = SortOptionModel(field: .name, direction: .asc)

        let next = SortOptionsReducer.reduce(state, .cancel)

        XCTAssertEqual(next.draft, .default)
        XCTAssertEqual(next.committed, .default)
    }
}

private final class EffectRecorder {
    var effects: [SortOptionsEffect] = []
}
