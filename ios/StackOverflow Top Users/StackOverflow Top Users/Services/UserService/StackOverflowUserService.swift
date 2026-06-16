import Foundation
import Networking


public struct StackOverflowUserService: UserServicing {
    private let client: any Client
    private let decoder = JSONDecoder()

    public init(client: any Client) {
        self.client = client
    }

    public func topUsers() async throws -> [StackOverflowUser] {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "api.stackexchange.com"
        components.path = "/2.2/users"
        components.queryItems = [
            URLQueryItem(name: "page", value: "1"),
            URLQueryItem(name: "pagesize", value: "20"),
            URLQueryItem(name: "order", value: "desc"),
            URLQueryItem(name: "sort", value: "reputation"),
            URLQueryItem(name: "site", value: "stackoverflow"),
        ]
        guard let url = components.url else {
            throw URLError(.badURL)
        }
        let (data, _) = try await client.data(from: url)
        let response = try decoder.decode(UsersResponse.self, from: data)
        return response.items
    }
}
