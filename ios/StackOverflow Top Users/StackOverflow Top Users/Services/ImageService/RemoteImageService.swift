import UIKit
import Networking

final class RemoteImageService: ImageLoading {
    private let client: any Client
    private let cache: any ImageCaching

    init(client: any Client, cache: any ImageCaching = NSCacheImageCache()) {
        self.client = client
        self.cache = cache
    }

    func image(from url: URL) async throws -> UIImage {
        let key = url.absoluteString
        if let cached = cache.image(for: key) {
            return cached
        }
        let (data, _) = try await client.data(from: url)
        guard let image = UIImage(data: data) else {
            throw ImageError.decodingFailed
        }
        cache.store(image, for: key)
        return image
    }
}
