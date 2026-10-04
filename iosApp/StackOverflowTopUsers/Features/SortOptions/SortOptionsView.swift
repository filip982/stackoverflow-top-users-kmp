import SwiftUI

struct SortOptionsView: View {
    @StateObject private var store: SortOptionsStore
    @Environment(\.dismiss) private var dismiss
    private let onApply: (SortOptionModel) -> Void

    init(initial: SortOptionModel, onApply: @escaping (SortOptionModel) -> Void) {
        _store = StateObject(wrappedValue: SortOptionsStore(initial: initial))
        self.onApply = onApply
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Sort by").font(.headline)
                    ForEach(SortFieldModel.allCases, id: \.self) { field in
                        RadioRow(label: field.label, isSelected: store.state.draft.field == field) {
                            store.dispatch(.selectField(field))
                        }
                        .accessibilityIdentifier(AccessibilityID.sortField(field.rawValue))
                    }

                    Text("Order").font(.headline).padding(.top, 16)
                    ForEach(SortDirectionModel.allCases, id: \.self) { direction in
                        RadioRow(label: direction.label, isSelected: store.state.draft.direction == direction) {
                            store.dispatch(.selectDirection(direction))
                        }
                        .accessibilityIdentifier(
                            direction == .asc ? AccessibilityID.sortDirectionAsc : AccessibilityID.sortDirectionDesc
                        )
                    }
                }
                .padding()
            }
            .safeAreaInset(edge: .bottom) {
                HStack(spacing: 12) {
                    Button("Cancel") { store.dispatch(.cancel) }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity)
                        .accessibilityIdentifier(AccessibilityID.sortCancel)
                    Button("Apply") { store.dispatch(.apply) }
                        .buttonStyle(.borderedProminent)
                        .frame(maxWidth: .infinity)
                        .accessibilityIdentifier(AccessibilityID.sortApply)
                }
                .padding()
                .background(.bar)
            }
            .navigationTitle("Sort users")
            .navigationBarTitleDisplayMode(.inline)
        }
        // Apply/Cancel are the only exits, so the draft semantics stay explicit.
        .interactiveDismissDisabled()
        .onAppear {
            store.onEffect = { [onApply, dismiss] effect in
                switch effect {
                case let .applied(option):
                    onApply(option)
                    dismiss()
                case .dismissed:
                    dismiss()
                }
            }
        }
    }
}

private struct RadioRow: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                Text(label)
                Spacer()
            }
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
