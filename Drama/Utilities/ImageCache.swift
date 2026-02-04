import Foundation
import SwiftUI
import UIKit
import Combine
import CryptoKit

enum ImageCacheError: Error {
    case invalidURL
    case decodingFailed
}

final class ImageCache {
    static let shared = ImageCache()

    private let memoryCache = NSCache<NSURL, NSData>()
    private let fileManager = FileManager.default
    private let diskCacheURL: URL

    init(directory: URL? = nil) {
        if let directory = directory {
            diskCacheURL = directory
        } else {
            let base = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
            diskCacheURL = base.appendingPathComponent("drama-image-cache", isDirectory: true)
        }

        if !fileManager.fileExists(atPath: diskCacheURL.path) {
            try? fileManager.createDirectory(at: diskCacheURL, withIntermediateDirectories: true)
        }
    }

    func data(for url: URL) -> Data? {
        let key = url as NSURL
        if let cached = memoryCache.object(forKey: key) {
            return Data(referencing: cached)
        }

        let fileURL = diskFileURL(for: url)
        guard let data = try? Data(contentsOf: fileURL) else {
            return nil
        }
        memoryCache.setObject(data as NSData, forKey: key)
        return data
    }

    func store(_ data: Data, for url: URL) {
        let key = url as NSURL
        memoryCache.setObject(data as NSData, forKey: key)

        let fileURL = diskFileURL(for: url)
        try? data.write(to: fileURL, options: [.atomic])
    }

    func clear() {
        memoryCache.removeAllObjects()
        try? fileManager.removeItem(at: diskCacheURL)
        try? fileManager.createDirectory(at: diskCacheURL, withIntermediateDirectories: true)
    }

    private func diskFileURL(for url: URL) -> URL {
        let filename = sha256(url.absoluteString)
        return diskCacheURL.appendingPathComponent(filename)
    }

    private func sha256(_ string: String) -> String {
        let data = Data(string.utf8)
        let hash = SHA256.hash(data: data)
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}

@MainActor
final class CachedImageLoader: ObservableObject {
    @Published var phase: AsyncImagePhase = .empty

    private let cache: ImageCache
    private var task: Task<Void, Never>?

    init(cache: ImageCache? = nil) {
        self.cache = cache ?? ImageCache.shared
    }

    func load(url: URL?) {
        task?.cancel()
        phase = .empty

        guard let url = url else {
            phase = .failure(ImageCacheError.invalidURL)
            return
        }

        task = Task {
            if let data = cache.data(for: url), let image = UIImage(data: data) {
                phase = .success(Image(uiImage: image))
                return
            }

            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if Task.isCancelled { return }

                cache.store(data, for: url)

                if let image = UIImage(data: data) {
                    phase = .success(Image(uiImage: image))
                } else {
                    phase = .failure(ImageCacheError.decodingFailed)
                }
            } catch {
                if Task.isCancelled { return }
                phase = .failure(error)
            }
        }
    }

    deinit {
        task?.cancel()
    }
}

struct CachedAsyncImage<Content: View>: View {
    let url: URL?
    let content: (AsyncImagePhase) -> Content

    @StateObject private var loader = CachedImageLoader()

    init(url: URL?, @ViewBuilder content: @escaping (AsyncImagePhase) -> Content) {
        self.url = url
        self.content = content
    }

    var body: some View {
        content(loader.phase)
            .task(id: url) {
                loader.load(url: url)
            }
    }
}
