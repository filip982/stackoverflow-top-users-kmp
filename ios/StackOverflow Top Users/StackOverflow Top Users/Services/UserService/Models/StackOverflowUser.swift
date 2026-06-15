import Foundation

public struct StackOverflowUser: Codable, Equatable, Identifiable, Sendable {
    public let id: Int
    public let name: String
    public let reputation: Int
    public let profileImageURL: URL?

    public init(id: Int, name: String, reputation: Int, profileImageURL: URL?) {
        self.id = id
        self.name = name
        self.reputation = reputation
        self.profileImageURL = profileImageURL
    }

    enum CodingKeys: String, CodingKey {
        case id = "user_id"
        case name = "display_name"
        case reputation
        case profileImageURL = "profile_image"
    }
}
