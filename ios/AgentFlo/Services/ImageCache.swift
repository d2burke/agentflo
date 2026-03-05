import UIKit
import CryptoKit

actor ImageCache {
    static let shared = ImageCache()

    private let memoryCache = NSCache<NSString, UIImage>()
    private let cacheDir: URL

    init() {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ImageCache", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        cacheDir = dir
        memoryCache.countLimit = 100
        memoryCache.totalCostLimit = 50_000_000 // 50 MB
    }

    func image(for key: String) -> UIImage? {
        // Check memory cache
        if let cached = memoryCache.object(forKey: key as NSString) {
            return cached
        }
        // Check disk cache
        let file = cacheDir.appendingPathComponent(hashedFilename(key))
        guard let data = try? Data(contentsOf: file),
              let image = UIImage(data: data) else { return nil }
        memoryCache.setObject(image, forKey: key as NSString, cost: data.count)
        return image
    }

    func store(_ image: UIImage, for key: String) {
        memoryCache.setObject(image, forKey: key as NSString)
        let file = cacheDir.appendingPathComponent(hashedFilename(key))
        Task.detached(priority: .utility) { [file] in
            try? image.jpegData(compressionQuality: 0.85)?.write(to: file, options: .atomic)
        }
    }

    func clear() {
        memoryCache.removeAllObjects()
        try? FileManager.default.removeItem(at: cacheDir)
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
    }

    private func hashedFilename(_ key: String) -> String {
        let hash = SHA256.hash(data: Data(key.utf8))
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}
