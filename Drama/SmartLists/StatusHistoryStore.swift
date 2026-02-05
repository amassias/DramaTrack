import Foundation

struct StatusHistory: Codable {
    let status: String
    let updatedAt: Date
}

final class StatusHistoryStore {
    static let shared = StatusHistoryStore()
    private let storageKey = "mdl_status_history"

    private init() {}

    func update(with dramas: [Drama]) {
        var store = loadAll()
        let now = Date()

        for drama in dramas {
            if let existing = store[drama.slug] {
                if existing.status != drama.status {
                    store[drama.slug] = StatusHistory(status: drama.status, updatedAt: now)
                }
            } else {
                store[drama.slug] = StatusHistory(status: drama.status, updatedAt: now)
            }
        }

        saveAll(store)
    }

    func history(for slug: String) -> StatusHistory? {
        loadAll()[slug]
    }

    private func loadAll() -> [String: StatusHistory] {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            return [:]
        }

        do {
            return try JSONDecoder().decode([String: StatusHistory].self, from: data)
        } catch {
            return [:]
        }
    }

    private func saveAll(_ store: [String: StatusHistory]) {
        guard let data = try? JSONEncoder().encode(store) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}
