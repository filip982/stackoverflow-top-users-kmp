import UIKit

final class UserDetailsViewController: UIViewController {
    private let viewModel: UserDetailsViewModel

    private let nameLabel = UILabel()
    private let repLabel = UILabel()
    private let avatarView = UIImageView()
    private var imageTask: Task<Void, Never>?
    private let followButton = UIButton(type: .system)

    init(viewModel: UserDetailsViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "User Details"
        view.backgroundColor = .systemBackground
        setupView()
        bindViewModel()
    }

    private func setupView() {
        avatarView.translatesAutoresizingMaskIntoConstraints = false
        avatarView.contentMode = .scaleAspectFill
        avatarView.clipsToBounds = true
        avatarView.layer.cornerRadius = 22
        avatarView.backgroundColor = .secondarySystemFill

        nameLabel.font = .preferredFont(forTextStyle: .headline)
        repLabel.font = .preferredFont(forTextStyle: .headline)

        followButton.titleLabel?.font = .preferredFont(forTextStyle: .subheadline)
        followButton.addAction(UIAction { [weak self] _ in
            self?.viewModel.toggleFollow()
            if let followed = self?.viewModel.isFollowed {
                self?.setFollowed(followed)
            }
        }, for: .touchUpInside)

        let vStack = UIStackView(arrangedSubviews: [avatarView, nameLabel, repLabel, followButton])
        vStack.axis = .vertical
        vStack.spacing = 12
        vStack.alignment = .center
        vStack.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(vStack)

        NSLayoutConstraint.activate([
            vStack.leadingAnchor.constraint(equalTo: self.view.layoutMarginsGuide.leadingAnchor),
            vStack.trailingAnchor.constraint(equalTo: self.view.layoutMarginsGuide.trailingAnchor),
            vStack.topAnchor.constraint(equalTo: self.view.layoutMarginsGuide.topAnchor),
            vStack.bottomAnchor.constraint(equalTo: self.view.layoutMarginsGuide.bottomAnchor),
            avatarView.widthAnchor.constraint(equalToConstant: 144),
            avatarView.heightAnchor.constraint(equalToConstant: 144),
        ])
    }

    func bindViewModel() {
        self.nameLabel.text = viewModel.nameString
        self.repLabel.text = viewModel.repString
        setFollowed(viewModel.isFollowed)
    }

    func setFollowed(_ followed: Bool) {
        followButton.setTitle(followed ? "Following" : "Follow", for: .normal)
        followButton.tintColor = followed ? .systemGray : .systemBlue
    }
}
