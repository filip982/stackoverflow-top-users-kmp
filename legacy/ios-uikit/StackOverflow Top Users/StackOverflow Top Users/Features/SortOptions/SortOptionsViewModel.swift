import Foundation

@MainActor
final class SortOptionsViewModel {
    private(set) var pendingSort: SortConfiguration

    var onUpdate: (() -> Void)?
    var onApply: ((SortConfiguration) -> Void)?
    var onCancel: (() -> Void)?

    init(currentSort: SortConfiguration) {
        self.pendingSort = currentSort
    }

    func select(option: SortOption) {
        pendingSort.option = option
        onUpdate?()
    }

    func select(order: SortOrder) {
        pendingSort.order = order
        onUpdate?()
    }

    func apply() {
        onApply?(pendingSort)
    }

    func cancel() {
        onCancel?()
    }
}
