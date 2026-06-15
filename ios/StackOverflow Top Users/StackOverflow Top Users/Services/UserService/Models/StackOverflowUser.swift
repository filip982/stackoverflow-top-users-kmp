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

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        let rawName = try container.decode(String.self, forKey: .name)
        name = rawName.decodingHTMLEntities()
        reputation = try container.decode(Int.self, forKey: .reputation)
        if let urlString = try container.decodeIfPresent(String.self, forKey: .profileImageURL) {
            profileImageURL = URL(string: urlString)
        } else {
            profileImageURL = nil
        }
    }
}

private extension String {
    func decodingHTMLEntities() -> String {
        var result = self
        let namedEntities: [(String, String)] = [
            ("&amp;", "&"), ("&lt;", "<"), ("&gt;", ">"),
            ("&quot;", "\""), ("&apos;", "'"), ("&nbsp;", "\u{00A0}"),
        ]
        for (entity, char) in namedEntities {
            result = result.replacingOccurrences(of: entity, with: char)
        }
        // numeric decimal: &#243;
        var out = ""
        var i = result.startIndex
        while i < result.endIndex {
            if result[i] == "&" {
                if let semi = result[i...].firstIndex(of: ";"),
                   result.distance(from: i, to: semi) <= 8 {
                    let inner = result[result.index(after: i)..<semi]
                    if inner.hasPrefix("#") {
                        let digits = inner.dropFirst()
                        if let code = UInt32(digits), let scalar = Unicode.Scalar(code) {
                            out.append(Character(scalar))
                            i = result.index(after: semi)
                            continue
                        }
                    }
                }
            }
            out.append(result[i])
            i = result.index(after: i)
        }
        return out
    }
}

