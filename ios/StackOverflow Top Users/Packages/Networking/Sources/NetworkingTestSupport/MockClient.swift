import Foundation
import Networking

public final class MockClient: Client, @unchecked Sendable {
    public enum Behavior {
        case success(Data, URLResponse)
        case httpStatus(Int)
        case failure(Error)
    }

    private let behavior: Behavior
    
    public init(behavior: Behavior) {
        self.behavior = behavior
    }

    public func data(from url: URL) async throws -> (Data, URLResponse) {
        switch behavior {
        case let .success(data, response):
            return (data, response)
        case let .httpStatus(code):
            let response = HTTPURLResponse(url: url, statusCode: code, httpVersion: nil, headerFields: nil)!
            return (Data(), response)
        case let .failure(error):
            throw error
        }
    }
}
