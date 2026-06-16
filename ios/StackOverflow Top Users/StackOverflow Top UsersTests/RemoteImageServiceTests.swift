import Testing
import UIKit
import Networking
import NetworkingTestSupport
@testable import StackOverflow_Top_Users

struct RemoteImageServiceTests {
    private let url = URL(string: "https://example.com/avatar.png")!

    private func okResponse() -> HTTPURLResponse {
        HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
    }

    private func pngData() -> Data {
        UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1))
            .image { _ in }
            .pngData()!
    }

    @Test func fetchesDecodesAndReturnsImage() async throws {
        let service = RemoteImageService(
            client: MockClient(behavior: .success(pngData(), okResponse()))
        )
        let image = try await service.image(from: url)
        #expect(image.size.width > 0)
    }

    @Test func cacheHitBypassesNetwork() async throws {
        // Pre-seed the cache, then point the client at a failure: if the network
        // is touched at all, the test throws and fails. A pass proves the cache hit.
        let cache = NSCacheImageCache()
        let seeded = UIImage(systemName: "star")!
        cache.store(seeded, for: url.absoluteString)

        let service = RemoteImageService(
            client: MockClient(behavior: .failure(URLError(.badServerResponse))),
            cache: cache
        )
        let image = try await service.image(from: url)
        #expect(image === seeded)
    }

    @Test func badDataThrowsDecodingFailed() async throws {
        let service = RemoteImageService(
            client: MockClient(behavior: .success(Data("not an image".utf8), okResponse()))
        )
        await #expect(throws: ImageError.decodingFailed) {
            _ = try await service.image(from: url)
        }
    }
}
