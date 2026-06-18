import UIKit

final class UserDetailsViewController: UIViewController {
    private let viewModel: UserDetailsViewModel
    private let imageLoader: any ImageLoading

    private let avatarView = UIImageView()
    private let nameLabel = UILabel()
    private let repLabel = UILabel()
    private let locationLabel = UILabel()
    private let websiteButton = UIButton(type: .system)
    private let followButton = UIButton(type: .system)
    private var imageTask: Task<Void, Never>?

    init(viewModel: UserDetailsViewModel, imageLoader: any ImageLoading) {
        self.viewModel = viewModel
        self.imageLoader = imageLoader
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
        avatarView.contentMode = .scaleAspectFill
        avatarView.clipsToBounds = true
        avatarView.backgroundColor = .secondarySystemFill

        nameLabel.font = .preferredFont(forTextStyle: .title2)
        nameLabel.textAlignment = .center

        repLabel.font = .preferredFont(forTextStyle: .subheadline)
        repLabel.textColor = .secondaryLabel
        repLabel.textAlignment = .center

        locationLabel.font = .preferredFont(forTextStyle: .subheadline)
        locationLabel.textColor = .secondaryLabel
        locationLabel.textAlignment = .center

        websiteButton.titleLabel?.font = .preferredFont(forTextStyle: .subheadline)
        websiteButton.addAction(UIAction { [weak self] _ in
            guard let url = self?.viewModel.websiteURL else { return }
            UIApplication.shared.open(url)
        }, for: .touchUpInside)

        followButton.titleLabel?.font = .preferredFont(forTextStyle: .body)
        followButton.addAction(UIAction { [weak self] _ in
            self?.viewModel.toggleFollow()
            self?.setFollowed(self?.viewModel.isFollowed ?? false)
        }, for: .touchUpInside)

        let vStack = UIStackView(arrangedSubviews: [avatarView, nameLabel, repLabel, locationLabel, websiteButton, followButton])
        vStack.axis = .vertical
        vStack.spacing = 8
        vStack.alignment = .center
        vStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(vStack)

        NSLayoutConstraint.activate([
            vStack.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            vStack.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
            vStack.topAnchor.constraint(equalTo: view.layoutMarginsGuide.topAnchor, constant: 24),
            avatarView.widthAnchor.constraint(equalToConstant: 144),
            avatarView.heightAnchor.constraint(equalToConstant: 144),
        ])
    }

    private func bindViewModel() {
        nameLabel.text = viewModel.nameString
        repLabel.text = viewModel.repString
        locationLabel.text = viewModel.locationString
        if let host = viewModel.websiteURL?.host {
            websiteButton.setTitle(host, for: .normal)
            websiteButton.isHidden = false
        } else {
            websiteButton.isHidden = true
        }
        setFollowed(viewModel.isFollowed)
        loadAvatar()
    }

    private func loadAvatar() {
        guard let url = viewModel.profileImageURL else { return }
        imageTask = Task {
            if let image = try? await imageLoader.image(from: url) {
                avatarView.image = image
            }
        }
    }

    private func setFollowed(_ followed: Bool) {
        followButton.setTitle(followed ? "Unfollow" : "Follow", for: .normal)
        followButton.tintColor = followed ? .systemGray : .systemBlue
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        avatarView.layer.cornerRadius = avatarView.bounds.width / 2
    }

    deinit {
        imageTask?.cancel()
    }
}
