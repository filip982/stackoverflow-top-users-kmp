import UIKit

final class UserListViewController: UIViewController {
    private let viewModel: UserListViewModel
    private let tableView = UITableView()
    private var users: [StackOverflowUser] = []
    private let imageLoader: any ImageLoading

    init(viewModel: UserListViewModel, imageLoader: any ImageLoading) {
        self.viewModel = viewModel
        self.imageLoader = imageLoader
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Stack Overflow"
        view.backgroundColor = .systemBackground
        setupTableView()
        bindViewModel()
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "arrow.up.arrow.down"),
            style: .plain,
            target: self,
            action: #selector(showSortOptions)
        )
        Task { await viewModel.load() }
    }

    private func setupTableView() {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UserCell.self, forCellReuseIdentifier: UserCell.reuseID)
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    private func bindViewModel() {
        viewModel.onChange = { [weak self] in
            self?.render()
        }
    }

    private func render() {
        switch viewModel.state {
        case .loading:
            tableView.backgroundView = makeMessageView(text: "Loading…", showRetry: false)
            users = []
            tableView.reloadData()
        case .loaded(let list):
            tableView.backgroundView = nil
            users = list
            tableView.reloadData()
        case .error(let message):
            users = []
            tableView.reloadData()
            tableView.backgroundView = makeMessageView(text: message, showRetry: true)
        }
    }

    private func makeMessageView(text: String, showRetry: Bool) -> UIView {
        let label = UILabel()
        label.text = text
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0

        let stack = UIStackView(arrangedSubviews: [label])
        stack.axis = .vertical
        stack.spacing = 12
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false

        if showRetry {
            let button = UIButton(type: .system)
            button.setTitle("Retry", for: .normal)
            button.addAction(UIAction { [weak self] _ in
                Task { await self?.viewModel.load() }
            }, for: .touchUpInside)
            stack.addArrangedSubview(button)
        }

        let container = UIView()
        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: container.leadingAnchor, constant: 32),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -32),
        ])
        return container
    }
}

extension UserListViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        users.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: UserCell.reuseID, for: indexPath) as! UserCell
        let user = users[indexPath.row]
        cell.configure(with: user, imageLoader: imageLoader)
        cell.setFollowed(viewModel.isFollowed(user))
        cell.onToggleFollow = { [weak self, weak cell] in
            guard let self else { return }
            self.viewModel.toggleFollow(user)
            cell?.setFollowed(self.viewModel.isFollowed(user))
        }
        return cell
    }
}

extension UserListViewController {
    @objc private func showSortOptions() {
        let sortVM = SortOptionsViewModel(currentSort: viewModel.currentSort)
        sortVM.onApply = { [weak self] config in
            self?.viewModel.applySort(config)
            self?.dismiss(animated: true)
        }
        sortVM.onCancel = { [weak self] in
            self?.dismiss(animated: true)
        }
        let sortVC = SortOptionsViewController(viewModel: sortVM)
        let nav = UINavigationController(rootViewController: sortVC)
        if let sheet = nav.sheetPresentationController {
            sheet.detents = [.medium()]
            sheet.prefersGrabberVisible = true
        }
        present(nav, animated: true)
    }
}

extension UserListViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let user = users[indexPath.row]
        self.viewModel.showUserDetails(user)
    }
}
