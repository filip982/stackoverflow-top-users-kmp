import SwiftUI

struct UserListView: View {
    @ObservedObject var store: UserListStore
    let onSelect: (UserModel) -> Void
    let onSort: () -> Void

    var body: some View {
        content
            .navigationTitle("Top users")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Sort", action: onSort)
                        .accessibilityIdentifier(AccessibilityID.sortButton)
                }
            }
            .overlay(alignment: .bottom) {
                MessageBanner(message: store.state.message) {
                    store.dispatch(.messageShown)
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        switch store.state.status {
        case .loading:
            ProgressView()
                .controlSize(.large)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityIdentifier(AccessibilityID.loading)
        case let .failed(error):
            MessageStateView(
                title: "Couldn't load users",
                message: error.userText,
                actionLabel: "Retry",
                action: { store.dispatch(.retry) }
            )
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier(AccessibilityID.errorState)
        case .empty:
            MessageStateView(
                title: "No users found",
                message: "Stack Overflow returned an empty list.",
                actionLabel: "Reload",
                action: { store.dispatch(.retry) }
            )
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier(AccessibilityID.emptyState)
        case .content:
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(store.state.users) { user in
                        UserRow(
                            user: user,
                            isFollowed: store.state.followedIds.contains(user.id),
                            isPending: store.state.pendingFollowIds.contains(user.id),
                            onSelect: { onSelect(user) },
                            onToggleFollow: { store.dispatch(.toggleFollow(userId: user.id)) }
                        )
                        Divider()
                    }
                }
            }
            .accessibilityIdentifier(AccessibilityID.userList)
        }
    }
}

private struct UserRow: View {
    let user: UserModel
    let isFollowed: Bool
    let isPending: Bool
    let onSelect: () -> Void
    let onToggleFollow: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            // The tappable row (avatar, name, reputation) is its own button so the follow button
            // and the followed indicator stay separate accessibility elements.
            Button(action: onSelect) {
                HStack(spacing: 12) {
                    AvatarView(url: user.avatarUrl, size: 48)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(user.displayName)
                            .font(.headline)
                            .lineLimit(1)
                        Text("Reputation: \(Formatting.reputation(user.reputation))")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(AccessibilityID.userRow(user.id))

            if isFollowed {
                FollowedIndicator()
                    .accessibilityIdentifier(AccessibilityID.followedIndicator(user.id))
            }

            FollowButton(isFollowed: isFollowed, isPending: isPending, action: onToggleFollow)
                .accessibilityIdentifier(AccessibilityID.followButton(user.id))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
