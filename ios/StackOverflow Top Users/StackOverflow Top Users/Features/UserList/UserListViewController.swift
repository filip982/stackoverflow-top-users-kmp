import UIKit
import Networking


final class UserListViewController: UIViewController {
    private let viewModel: UserListViewModel

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Stack Overflow"
        label.font = .preferredFont(forTextStyle: .largeTitle)
        label.textColor = .label
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    init(viewModel: UserListViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupTitleLabel()
        Task { await viewModel.load() }
    }

    private func setupTitleLabel() {
        view.addSubview(titleLabel)
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(
                equalTo: view.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(
                equalTo: view.trailingAnchor, constant: -16),
        ])
    }
}
