import Testing
import Foundation
@testable import StackOverflow_Top_Users

@MainActor
struct SortOptionsViewModelTests {

    @Test func initialSortMatchesConstructorArg() {
        let config = SortConfiguration(option: .name, order: .ascending)
        let vm = SortOptionsViewModel(currentSort: config)
        #expect(vm.pendingSort == config)
    }

    @Test func selectOptionUpdatesPendingSort() {
        let vm = SortOptionsViewModel(currentSort: SortConfiguration())
        vm.select(option: .creation)
        #expect(vm.pendingSort.option == .creation)
    }

    @Test func selectOrderUpdatesPendingSort() {
        let vm = SortOptionsViewModel(currentSort: SortConfiguration())
        vm.select(order: .ascending)
        #expect(vm.pendingSort.order == .ascending)
    }

    @Test func selectOptionFiresOnUpdate() {
        let vm = SortOptionsViewModel(currentSort: SortConfiguration())
        var fired = false
        vm.onUpdate = { fired = true }
        vm.select(option: .modified)
        #expect(fired)
    }

    @Test func selectOrderFiresOnUpdate() {
        let vm = SortOptionsViewModel(currentSort: SortConfiguration())
        var fired = false
        vm.onUpdate = { fired = true }
        vm.select(order: .ascending)
        #expect(fired)
    }

    @Test func applyFiresOnApplyWithPendingSort() {
        let vm = SortOptionsViewModel(currentSort: SortConfiguration())
        vm.select(option: .name)
        vm.select(order: .ascending)
        var received: SortConfiguration?
        vm.onApply = { received = $0 }
        vm.apply()
        #expect(received == SortConfiguration(option: .name, order: .ascending))
    }

    @Test func cancelFiresOnCancel() {
        let vm = SortOptionsViewModel(currentSort: SortConfiguration())
        var fired = false
        vm.onCancel = { fired = true }
        vm.cancel()
        #expect(fired)
    }
}
