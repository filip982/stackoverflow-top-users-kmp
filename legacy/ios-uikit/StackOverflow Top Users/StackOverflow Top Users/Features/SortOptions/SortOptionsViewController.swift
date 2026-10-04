import UIKit

final class SortOptionsViewController: UIViewController {
    private let viewModel: SortOptionsViewModel

    private var radioButtons: [SortOption: UIButton] = [:]
    private let orderControl = UISegmentedControl(items: SortOrder.allCases.map { $0.title })

    init(viewModel: SortOptionsViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Sort Options"
        view.backgroundColor = .systemBackground
        setupView()
        viewModel.onUpdate = { [weak self] in self?.render() }
        render()
    }

    private func setupView() {
        let radioStack = UIStackView()
        radioStack.axis = .vertical
        radioStack.spacing = 4

        for option in SortOption.allCases {
            var config = UIButton.Configuration.plain()
            config.imagePadding = 10
            config.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 0, bottom: 10, trailing: 0)
            let button = UIButton(configuration: config)
            button.contentHorizontalAlignment = .left
            button.addAction(UIAction { [weak self] _ in
                self?.viewModel.select(option: option)
            }, for: .touchUpInside)
            radioButtons[option] = button
            radioStack.addArrangedSubview(button)
        }

        orderControl.addTarget(self, action: #selector(orderChanged), for: .valueChanged)

        var applyConfig = UIButton.Configuration.filled()
        applyConfig.title = "Apply"
        let applyButton = UIButton(configuration: applyConfig)
        applyButton.addAction(UIAction { [weak self] _ in self?.viewModel.apply() }, for: .touchUpInside)

        var cancelConfig = UIButton.Configuration.plain()
        cancelConfig.title = "Cancel"
        let cancelButton = UIButton(configuration: cancelConfig)
        cancelButton.addAction(UIAction { [weak self] _ in self?.viewModel.cancel() }, for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [radioStack, orderControl, applyButton, cancelButton])
        stack.axis = .vertical
        stack.spacing = 20
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
            stack.topAnchor.constraint(equalTo: view.layoutMarginsGuide.topAnchor, constant: 24),
        ])
    }

    private func render() {
        for (option, button) in radioButtons {
            let selected = viewModel.pendingSort.option == option
            let imageName = selected ? "circle.inset.filled" : "circle"
            var config = button.configuration ?? UIButton.Configuration.plain()
            config.image = UIImage(systemName: imageName)
            config.title = option.title
            config.baseForegroundColor = selected ? .systemBlue : .label
            button.configuration = config
        }
        let orderIndex = SortOrder.allCases.firstIndex(of: viewModel.pendingSort.order) ?? 0
        orderControl.selectedSegmentIndex = orderIndex
    }

    @objc private func orderChanged() {
        let order = SortOrder.allCases[orderControl.selectedSegmentIndex]
        viewModel.select(order: order)
    }
}
