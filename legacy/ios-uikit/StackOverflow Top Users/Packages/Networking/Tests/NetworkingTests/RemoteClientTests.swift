import Testing
import Foundation
@testable import Networking

struct RemoteClientTests {
    @Test func successPassthrough() async throws {
        let url = URL(string: "https://example.com")!
        let expectedData = Data("hello".utf8)
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
        StubURLProtocol.stub(url: url, data: expectedData, response: response)
        let client = RemoteClient(session: URLSession(configuration: stubConfiguration()))
        let (data, _) = try await client.data(from: url)
        #expect(data == expectedData)
    }
    
    @Test func invalidStatusThrows() async throws {
        let url = URL(string: "https://example.com/error")!
        let response = HTTPURLResponse(url: url, statusCode: 404, httpVersion: nil, headerFields: nil)!
        StubURLProtocol.stub(url: url, data: Data(), response: response)
        let client = RemoteClient(session: URLSession(configuration: stubConfiguration()))
        await #expect(throws: NetworkError.invalidResponse(statusCode: 404)) {
            _ = try await client.data(from: url)
        }
    }
    
    @Test func transportErrorPropagates() async throws {
        let url = URL(string: "https://example.com/transport")!
        StubURLProtocol.stub(url: url, error: URLError(.notConnectedToInternet))
        let client = RemoteClient(session: URLSession(configuration: stubConfiguration()))
        await #expect(throws: NetworkError.transport(URLError(.notConnectedToInternet))) {
            _ = try await client.data(from: url)
        }
    }
    
    private func stubConfiguration() -> URLSessionConfiguration {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        return config
    }
}

final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    private struct Stub {
        var data: Data?
        var response: URLResponse?
        var error: Error?
    }
    
    nonisolated(unsafe) private static var stubs: [URL: Stub] = [:]

    static func stub(url: URL, data: Data = Data(), response: URLResponse) {
        stubs[url] = Stub(data: data, response: response, error: nil)
    }

    static func stub(url: URL, error: Error) {
        stubs[url] = Stub(data: nil, response: nil, error: error)
    }

    override class func canInit(with request: URLRequest) -> Bool {
        guard let url = request.url else { return false }
        return stubs[url] != nil
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url, let stub = Self.stubs[url] else { return }
        if let error = stub.error {
            client?.urlProtocol(self, didFailWithError: error)
        } else {
            if let response = stub.response {
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            }
            if let data = stub.data {
                client?.urlProtocol(self, didLoad: data)
            }
            client?.urlProtocolDidFinishLoading(self)
        }
    }

    override func stopLoading() {}
}
