import UIKit

final class UserListViewController: UIViewController {

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Stack Overflow"
        label.font = .preferredFont(forTextStyle: .largeTitle)
        label.textColor = .label
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupTitleLabel()
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
