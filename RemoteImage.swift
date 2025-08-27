//
//  RemoteImage.swift
//  FitSpo
//
//  Lightweight remote‑image loader with URLCache + retry
//

import SwiftUI
import UIKit       // UIImage

struct RemoteImage: View {

    enum Phase: Equatable {
        case empty
        case success(UIImage)
        case failure

        static func == (lhs: Phase, rhs: Phase) -> Bool {
            switch (lhs, rhs) {
            case (.empty, .empty), (.failure, .failure):
                return true
            case (.success, .success):
                // consider any success state equal; the image itself isn't compared
                return true
            default:
                return false
            }
        }
    }

    @StateObject private var loader: Loader
    private let contentMode: ContentMode

    init(url: String,
         contentMode: ContentMode = .fit)
    {
        _loader      = StateObject(wrappedValue: Loader(urlString: url))
        self.contentMode = contentMode
    }

    var body: some View {
        Group {
            switch loader.phase {
            case .empty:
                ZStack {
                    Color.gray.opacity(0.12)
                    ProgressView()
                }

            case .success(let img):
                Image(uiImage: img)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)

            case .failure:
                ZStack {
                    Color.gray.opacity(0.12)
                    Image(systemName: "photo")
                        .font(.largeTitle)
                        .foregroundColor(.white.opacity(0.7))
                }
                .onTapGesture { loader.resetAndReload() }  // manual retry
            }
        }
        .onAppear { loader.load() }
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: Loader (ObservableObject)
// ─────────────────────────────────────────────────────────────
private extension RemoteImage {

    @MainActor
    final class Loader: ObservableObject {

        @Published var phase: Phase = .empty

        private let urlString: String
        private var attempts  = 0

        init(urlString: String) { self.urlString = urlString }

        func load() {
            // only start when we're still in .empty
            guard case .empty = phase,
                  let url = URL(string: urlString) else { return }

            // 0️⃣ check in‑memory cache first to avoid any flicker
            if let cached = ImageCache.shared.image(forKey: urlString) {
                phase = .success(cached)
                return
            }

            // 1️⃣ check URLCache
            if let cached = URLCache.shared.cachedResponse(for: URLRequest(url: url)),
               let img     = UIImage(data: cached.data) {
                ImageCache.shared.set(img, forKey: urlString)
                phase = .success(img)
                return
            }

            attempts += 1
            Task.detached { [urlString] in
                do {
                    let (data, response) = try await URLSession.shared.data(from: url)
                    if let img = UIImage(data: data) {
                        // save to caches
                        let cached = CachedURLResponse(response: response, data: data)
                        URLCache.shared.storeCachedResponse(cached,
                                                            for: URLRequest(url: url))
                        ImageCache.shared.set(img, forKey: urlString)
                        await MainActor.run { self.phase = .success(img) }
                    } else {
                        throw URLError(.cannotDecodeContentData)
                    }
                } catch {
                    await MainActor.run { self.handleFailure() }
                }
            }
        }

        func resetAndReload() {
            phase   = .empty
            attempts = 0
            load()
        }

        private func handleFailure() {
            if attempts <= 1 {
                // one quick retry
                load()
            } else {
                phase = .failure
            }
        }
    }
}
