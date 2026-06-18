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

        let detailsStack = UIStackView(arrangedSubviews: [
            makeRow(label: "Name", valueView: nameLabel),
            makeRow(label: "Reputation", valueView: repLabel),
            makeRow(label: "Location", valueView: locationLabel),
            makeRow(label: "Website", valueView: websiteButton),
        ])
        detailsStack.axis = .vertical
        detailsStack.spacing = 10

        websiteButton.contentHorizontalAlignment = .left
        websiteButton.addAction(UIAction { [weak self] _ in
            guard let url = self?.viewModel.websiteURL else { return }
            UIApplication.shared.open(url)
        }, for: .touchUpInside)

        var followConfig = UIButton.Configuration.bordered()
        followConfig.cornerStyle = .medium
        followButton.configuration = followConfig
        followButton.addAction(UIAction { [weak self] _ in
            self?.viewModel.toggleFollow()
            self?.setFollowed(self?.viewModel.isFollowed ?? false)
        }, for: .touchUpInside)

        let outerStack = UIStackView(arrangedSubviews: [avatarView, detailsStack, followButton])
        outerStack.axis = .vertical
        outerStack.spacing = 24
        outerStack.alignment = .center
        outerStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(outerStack)

        NSLayoutConstraint.activate([
            outerStack.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            outerStack.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
            outerStack.topAnchor.constraint(equalTo: view.layoutMarginsGuide.topAnchor, constant: 24),
            avatarView.widthAnchor.constraint(equalToConstant: 144),
            avatarView.heightAnchor.constraint(equalToConstant: 144),
            detailsStack.widthAnchor.constraint(equalTo: outerStack.widthAnchor),
        ])
    }

    private func makeRow(label: String, valueView: UIView) -> UIStackView {
        let titleLabel = UILabel()
        titleLabel.text = label + ":"
        titleLabel.font = .preferredFont(forTextStyle: .subheadline)
        titleLabel.textColor = .secondaryLabel
        titleLabel.setContentHuggingPriority(.required, for: .horizontal)

        let row = UIStackView(arrangedSubviews: [titleLabel, valueView])
        row.axis = .horizontal
        row.spacing = 6
        row.alignment = .firstBaseline
        return row
    }

    private func bindViewModel() {
        nameLabel.text = viewModel.nameString
        nameLabel.font = .preferredFont(forTextStyle: .subheadline)
        repLabel.text = viewModel.repString
        repLabel.font = .preferredFont(forTextStyle: .subheadline)
        locationLabel.text = viewModel.locationString
        locationLabel.font = .preferredFont(forTextStyle: .subheadline)
        locationLabel.textColor = .label
        websiteButton.setTitle(viewModel.websiteURL?.host ?? "N/A", for: .normal)
        websiteButton.isEnabled = viewModel.websiteURL != nil
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
        followButton.configuration?.title = followed ? "Unfollow" : "Follow"
        followButton.configuration?.baseBackgroundColor = followed ? .systemGray5 : .systemBlue.withAlphaComponent(0.1)
        followButton.tintColor = followed ? .secondaryLabel : .systemBlue
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        avatarView.layer.cornerRadius = avatarView.bounds.width / 2
    }

    deinit {
        imageTask?.cancel()
    }
}
