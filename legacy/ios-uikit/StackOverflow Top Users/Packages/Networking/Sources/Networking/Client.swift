import Foundation

public protocol Client: Sendable {
    func data(from url: URL) async throws -> (Data, URLResponse)
}
