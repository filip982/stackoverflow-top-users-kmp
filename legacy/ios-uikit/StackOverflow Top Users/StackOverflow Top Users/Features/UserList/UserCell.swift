import UIKit

final class UserCell: UITableViewCell {
    static let reuseID = "UserCell"

    private let nameLabel = UILabel()
    private let repLabel = UILabel()
    private let avatarView = UIImageView()
    private var imageTask: Task<Void, Never>?
    private let followButton = UIButton(type: .system)
    var onToggleFollow: (() -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setup()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        nameLabel.font = .preferredFont(forTextStyle: .headline)
        repLabel.font = .preferredFont(forTextStyle: .subheadline)
        repLabel.textColor = .secondaryLabel

        avatarView.translatesAutoresizingMaskIntoConstraints = false
        avatarView.contentMode = .scaleAspectFill
        avatarView.clipsToBounds = true
        avatarView.layer.cornerRadius = 22
        avatarView.backgroundColor = .secondarySystemFill

        let textStack = UIStackView(arrangedSubviews: [nameLabel, repLabel])
        textStack.axis = .vertical
        textStack.spacing = 2

        followButton.titleLabel?.font = .preferredFont(forTextStyle: .subheadline)
        followButton.setContentHuggingPriority(.required, for: .horizontal)
        followButton.addAction(UIAction { [weak self] _ in
            self?.onToggleFollow?()
        }, for: .touchUpInside)

        let hStack = UIStackView(arrangedSubviews: [avatarView, textStack, followButton])
        hStack.axis = .horizontal
        hStack.spacing = 12
        hStack.alignment = .center
        hStack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(hStack)

        NSLayoutConstraint.activate([
            hStack.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            hStack.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
            hStack.topAnchor.constraint(equalTo: contentView.layoutMarginsGuide.topAnchor),
            hStack.bottomAnchor.constraint(equalTo: contentView.layoutMarginsGuide.bottomAnchor),
            avatarView.widthAnchor.constraint(equalToConstant: 44),
            avatarView.heightAnchor.constraint(equalToConstant: 44),
        ])
    }

    func setFollowed(_ followed: Bool) {
        followButton.setTitle(followed ? "Following" : "Follow", for: .normal)
        followButton.tintColor = followed ? .systemGray : .systemBlue
    }

    func configure(with user: StackOverflowUser, imageLoader: any ImageLoading) {
        nameLabel.text = user.name
        repLabel.text = "rep " + user.reputation.formatted(.number.grouping(.automatic))
        avatarView.image = nil
        guard let url = user.profileImageURL else { return }
        imageTask = Task { @MainActor in
            if let image = try? await imageLoader.image(from: url) {
                self.avatarView.image = image
            }
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        imageTask?.cancel()
        avatarView.image = nil
        onToggleFollow = nil
    }
}
