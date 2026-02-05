import Foundation

struct AiringEpisode: Codable {
    let number: Int
    let airDate: Date
}

struct AiringCacheEntry: Codable {
    let fetchedAt: Date
    let episodes: [AiringEpisode]
}

final class SmartListAiringCache {
    static let shared = SmartListAiringCache()
    private let storageKey = "mdl_airing_cache"
    private let maxAge: TimeInterval = 24 * 60 * 60

    private init() {}

    func getEpisodes(for slug: String) -> [AiringEpisode]? {
        guard let entry = loadAll()[slug] else { return nil }
        let age = Date().timeIntervalSince(entry.fetchedAt)
        if age > maxAge {
            return nil
        }
        return entry.episodes
    }

    func setEpisodes(_ episodes: [AiringEpisode], for slug: String) {
        var store = loadAll()
        store[slug] = AiringCacheEntry(fetchedAt: Date(), episodes: episodes)
        saveAll(store)
    }

    private func loadAll() -> [String: AiringCacheEntry] {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            return [:]
        }
        do {
            return try JSONDecoder().decode([String: AiringCacheEntry].self, from: data)
        } catch {
            return [:]
        }
    }

    private func saveAll(_ store: [String: AiringCacheEntry]) {
        guard let data = try? JSONEncoder().encode(store) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}
