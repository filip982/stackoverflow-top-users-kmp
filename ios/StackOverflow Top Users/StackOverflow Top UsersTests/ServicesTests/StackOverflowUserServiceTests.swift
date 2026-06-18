import Testing
import Foundation
import NetworkingTestSupport
@testable import StackOverflow_Top_Users

struct StackOverflowUserServiceTests {
    private func makeService(behavior: MockClient.Behavior) -> StackOverflowUserService {
        StackOverflowUserService(client: MockClient(behavior: behavior))
    }

    private func successService(json: String) -> StackOverflowUserService {
        let data = json.data(using: .utf8)!
        let url = URL(string: "https://api.stackexchange.com")!
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
        return makeService(behavior: .success(data, response))
    }

    @Test func decodesHappyPath() async throws {
        let service = successService(json: """
        {"items":[{"user_id":22656,"display_name":"Jon Skeet","reputation":1454978,"profile_image":"https://example.com/avatar.jpg"}]}
        """)
        let users = try await service.topUsers(sort: SortConfiguration())
        #expect(users.count == 1)
        #expect(users[0].id == 22656)
        #expect(users[0].name == "Jon Skeet")
        #expect(users[0].reputation == 1454978)
        #expect(users[0].profileImageURL == URL(string: "https://example.com/avatar.jpg"))
    }

    @Test func missingOptionalProfileImage() async throws {
        let service = successService(json: """
        {"items":[{"user_id":1,"display_name":"No Image","reputation":100}]}
        """)
        let users = try await service.topUsers(sort: SortConfiguration())
        #expect(users[0].profileImageURL == nil)
    }

    @Test func malformedJSONThrows() async throws {
        let service = successService(json: "not json")
        await #expect(throws: (any Error).self) {
            _ = try await service.topUsers(sort: SortConfiguration())
        }
    }

    @Test func networkErrorPropagates() async throws {
        let service = makeService(behavior: .failure(URLError(.notConnectedToInternet)))
        await #expect(throws: (any Error).self) {
            _ = try await service.topUsers(sort: SortConfiguration())
        }
    }

    @Test func decodesHTMLEntities() async throws {
        let service = successService(json: """
        {"items":[{"user_id":2,"display_name":"Andr&#243;s","reputation":500}]}
        """)
        let users = try await service.topUsers(sort: SortConfiguration())
        #expect(users[0].name == "Andr\u{00F3}s")
    }

    @Test func sortParamsArePassedToURL() async throws {
        final class CapturingClient: Client, @unchecked Sendable {
            var lastURL: URL?
            func data(from url: URL) async throws -> (Data, URLResponse) {
                lastURL = url
                let json = #"{"items":[]}"#.data(using: .utf8)!
                let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (json, response)
            }
        }
        let client = CapturingClient()
        let service = StackOverflowUserService(client: client)
        let sort = SortConfiguration(option: .name, order: .ascending)
        _ = try await service.topUsers(sort: sort)
        let components = URLComponents(url: client.lastURL!, resolvingAgainstBaseURL: false)!
        let items = components.queryItems ?? []
        #expect(items.first(where: { $0.name == "sort" })?.value == "name")
        #expect(items.first(where: { $0.name == "order" })?.value == "asc")
    }
}
