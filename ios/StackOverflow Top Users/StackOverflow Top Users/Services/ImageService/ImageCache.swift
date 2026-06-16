import UIKit

protocol ImageCaching: Sendable {
    func image(for key: String) -> UIImage?
    func store(_ image: UIImage, for key: String)
}

final class NSCacheImageCache: ImageCaching, @unchecked Sendable {
    private let cache = NSCache<NSString, UIImage>()

    init() {}

    func image(for key: String) -> UIImage? {
        cache.object(forKey: key as NSString)
    }

    func store(_ image: UIImage, for key: String) {
        cache.setObject(image, forKey: key as NSString)
    }
}
