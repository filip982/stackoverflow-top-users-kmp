import Testing
import Foundation
import NetworkingTestSupport
@testable import StackOverflow_Top_Users

struct StackOverflowUserServiceTests {
    private func makeService(behavior: MockClient.Behavior) -> StackOverflowUserService {
        StackOverflowUserService(client: MockClient(behavior: behavior))
    }

    @Test func decodesHappyPath() async throws {
        let json = """
        {"items":[{"user_id":22656,"display_name":"Jon Skeet","reputation":1454978,"profile_image":"https://example.com/avatar.jpg"}]}
        """.data(using: .utf8)!
        let url = URL(string: "https://api.stackexchange.com")!
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
        let service = makeService(behavior: .success(json, response))
        let users = try await service.topUsers()
        #expect(users.count == 1)
        #expect(users[0].id == 22656)
        #expect(users[0].name == "Jon Skeet")
        #expect(users[0].reputation == 1454978)
        #expect(users[0].profileImageURL == URL(string: "https://example.com/avatar.jpg"))
    }

    @Test func missingOptionalProfileImage() async throws {
        let json = """
        {"items":[{"user_id":1,"display_name":"No Image","reputation":100}]}
        """.data(using: .utf8)!
        let url = URL(string: "https://api.stackexchange.com")!
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
        let service = makeService(behavior: .success(json, response))
        let users = try await service.topUsers()
        #expect(users[0].profileImageURL == nil)
    }

    @Test func malformedJSONThrows() async throws {
        let json = Data("not json".utf8)
        let url = URL(string: "https://api.stackexchange.com")!
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
        let service = makeService(behavior: .success(json, response))
        await #expect(throws: (any Error).self) {
            _ = try await service.topUsers()
        }
    }

    @Test func networkErrorPropagates() async throws {
        let service = makeService(behavior: .failure(URLError(.notConnectedToInternet)))
        await #expect(throws: (any Error).self) {
            _ = try await service.topUsers()
        }
    }

    @Test func decodesHTMLEntities() async throws {
        let json = """
        {"items":[{"user_id":2,"display_name":"Andr&#243;s","reputation":500}]}
        """.data(using: .utf8)!
        let url = URL(string: "https://api.stackexchange.com")!
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
        let service = makeService(behavior: .success(json, response))
        let users = try await service.topUsers()
        #expect(users[0].name == "Andr\u{00F3}s")
    }
}
