import SwiftUI

struct UserDetailView: View {
    @StateObject private var store: UserDetailStore

    init(user: UserModel, gateway: CoreGateway) {
        _store = StateObject(wrappedValue: UserDetailStore(user: user, gateway: gateway))
    }

    var body: some View {
        let user = store.state.user
        ScrollView {
            VStack(spacing: 16) {
                AvatarView(url: user.avatarUrl, size: 120)
                    .padding(.top, 24)

                HStack(spacing: 6) {
                    Text(user.displayName)
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)
                        .accessibilityIdentifier(AccessibilityID.detailName)
                    if store.state.isFollowed {
                        FollowedIndicator()
                            .accessibilityIdentifier(AccessibilityID.detailFollowedIndicator)
                    }
                }

                Text("Reputation: \(Formatting.reputation(user.reputation))")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier(AccessibilityID.detailReputation)

                FollowButton(
                    isFollowed: store.state.isFollowed,
                    isPending: store.state.isTogglePending,
                    action: { store.dispatch(.toggleFollow) }
                )
                .accessibilityIdentifier(AccessibilityID.detailFollow)

                VStack(alignment: .leading, spacing: 12) {
                    if let location = user.location {
                        DetailField(label: "Location") {
                            Text(location)
                                .accessibilityIdentifier(AccessibilityID.detailLocation)
                        }
                    }
                    if let website = user.websiteUrl, let url = URL(string: website) {
                        DetailField(label: "Website") {
                            Link(website, destination: url)
                                .accessibilityIdentifier(AccessibilityID.detailWebsite)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
            }
            .frame(maxWidth: .infinity)
        }
        .navigationTitle(user.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .overlay(alignment: .bottom) {
            MessageBanner(message: store.state.message) {
                store.dispatch(.messageShown)
            }
        }
    }
}

private struct DetailField<Content: View>: View {
    let label: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            content()
        }
    }
}
