import UIKit

protocol ImageLoading: Sendable {
    func image(from url: URL) async throws -> UIImage
}

enum ImageError: Error {
    case decodingFailed
}
