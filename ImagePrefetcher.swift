import Foundation
import UIKit

final class ImagePrefetcher {
    static let shared = ImagePrefetcher()
    private init() {}

    // Limit concurrency so we don't spawn hundreds of downloads at once
    private let maxConcurrent = 6

    // Queue of urls waiting to be prefetched
    private var queue: [String] = []
    private var running: Set<String> = []

    private let lock = NSLock()

    func prefetch(urlStrings: [String]) {
        lock.lock(); defer { lock.unlock() }
        for u in urlStrings {
            guard !running.contains(u), !queue.contains(u), let _ = URL(string: u) else { continue }
            if ImageCache.shared.image(forKey: u) != nil { continue }
            queue.append(u)
        }
        kickOffIfPossible()
    }

    private func kickOffIfPossible() {
        while running.count < maxConcurrent, !queue.isEmpty {
            let u = queue.removeFirst()
            guard let url = URL(string: u) else { continue }
            running.insert(u)
            Task.detached { [weak self] in
                defer {
                    DispatchQueue.main.async {
                        self?.lock.lock(); self?.running.remove(u); self?.lock.unlock()
                        self?.kickOffIfPossible()
                    }
                }
                do {
                    // Favor cache if possible
                    var req = URLRequest(url: url)
                    req.cachePolicy = .returnCacheDataElseLoad
                    let (data, response) = try await URLSession.shared.data(for: req)
                    if let img = UIImage(data: data) {
                        ImageCache.shared.set(img, forKey: u)
                        let cached = CachedURLResponse(response: response, data: data)
                        URLCache.shared.storeCachedResponse(cached, for: req)
                    }
                } catch {
                    // ignore errors; best-effort prefetch
                }
            }
        }
    }
} 