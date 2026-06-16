import UIKit

final class UserCell: UITableViewCell {
    static let reuseID = "UserCell"

    private let nameLabel = UILabel()
    private let repLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setup()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setup() {
        nameLabel.font = .preferredFont(forTextStyle: .headline)
        repLabel.font = .preferredFont(forTextStyle: .subheadline)
        repLabel.textColor = .secondaryLabel

        let stack = UIStackView(arrangedSubviews: [nameLabel, repLabel])
        stack.axis = .vertical
        stack.spacing = 2
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
            stack.topAnchor.constraint(equalTo: contentView.layoutMarginsGuide.topAnchor),
            stack.bottomAnchor.constraint(equalTo: contentView.layoutMarginsGuide.bottomAnchor),
        ])
    }

    func configure(with user: StackOverflowUser) {
        nameLabel.text = user.name
        repLabel.text = "rep " + user.reputation.formatted(.number.grouping(.automatic))
    }
}
