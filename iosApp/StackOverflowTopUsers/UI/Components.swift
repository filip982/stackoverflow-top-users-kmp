import SwiftUI

struct AvatarView: View {
    let url: String?
    let size: CGFloat

    var body: some View {
        AsyncImage(url: url.flatMap { URL(string: $0) }) { phase in
            if let image = phase.image {
                image.resizable().scaledToFill()
            } else {
                Circle().fill(Color.secondary.opacity(0.2))
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .accessibilityHidden(true)
    }
}

struct FollowButton: View {
    let isFollowed: Bool
    let isPending: Bool
    let action: () -> Void

    var body: some View {
        Group {
            if isFollowed {
                Button("Unfollow", action: action).buttonStyle(.bordered)
            } else {
                Button("Follow", action: action).buttonStyle(.borderedProminent)
            }
        }
        .disabled(isPending)
    }
}

struct FollowedIndicator: View {
    var body: some View {
        Image(systemName: "star.fill")
            .foregroundStyle(Color.accentColor)
            .accessibilityLabel("Followed")
    }
}

/// Full-screen notice with an action (error and empty states).
struct MessageStateView: View {
    let title: String
    let message: String
    let actionLabel: String
    let action: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Text(title).font(.title3.bold()).multilineTextAlignment(.center)
            Text(message).font(.body).multilineTextAlignment(.center).foregroundStyle(.secondary)
            Button(actionLabel, action: action)
                .buttonStyle(.borderedProminent)
                .padding(.top, 12)
                .accessibilityIdentifier(AccessibilityID.retry)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Snackbar-like transient notice; reports itself consumed after a few seconds.
struct MessageBanner: View {
    let message: UserMessage?
    let onShown: () -> Void

    var body: some View {
        if let message {
            Text(message.text)
                .font(.callout)
                .padding(12)
                .frame(maxWidth: .infinity)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
                .padding()
                .accessibilityIdentifier(AccessibilityID.messageBanner)
                .task(id: message) {
                    try? await Task.sleep(nanoseconds: 4_000_000_000)
                    if !Task.isCancelled {
                        onShown()
                    }
                }
        }
    }
}
