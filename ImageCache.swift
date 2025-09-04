import UIKit

final class ImageCache {
    static let shared = ImageCache()
    private init() {
        cache.countLimit = 500
        cache.totalCostLimit = 50 * 1024 * 1024 // ~50MB
    }

    private let cache = NSCache<NSString, UIImage>()

    func image(forKey key: String) -> UIImage? {
        cache.object(forKey: key as NSString)
    }

    func set(_ image: UIImage, forKey key: String) {
        let cost = Int(image.size.width * image.size.height)
        cache.setObject(image, forKey: key as NSString, cost: cost)
    }
} 
