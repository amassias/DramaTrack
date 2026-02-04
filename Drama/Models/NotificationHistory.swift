import Foundation

struct NotificationHistoryItem: Identifiable, Codable, Hashable {
    let id: String
    let slug: String
    let title: String
    let episodeNumber: Int?
    let airDate: Date?
    let scheduledAt: Date
    var deliveredAt: Date?
}

final class NotificationHistoryStore {
    static let shared = NotificationHistoryStore()

    private let historyKey = "mdl_notification_history"
    private let maxItems = 200

    func load() -> [NotificationHistoryItem] {
        guard let data = UserDefaults.standard.data(forKey: historyKey) else { return [] }
        return (try? JSONDecoder().decode([NotificationHistoryItem].self, from: data)) ?? []
    }

    func save(_ items: [NotificationHistoryItem]) {
        let trimmed = Array(items.prefix(maxItems))
        if let data = try? JSONEncoder().encode(trimmed) {
            UserDefaults.standard.set(data, forKey: historyKey)
        }
    }

    func upsertScheduled(id: String, slug: String, title: String, episodeNumber: Int?, airDate: Date?) {
        var items = load()
        if items.contains(where: { $0.id == id }) {
            return
        }

        let item = NotificationHistoryItem(
            id: id,
            slug: slug,
            title: title,
            episodeNumber: episodeNumber,
            airDate: airDate,
            scheduledAt: Date(),
            deliveredAt: nil
        )
        items.insert(item, at: 0)
        save(items)
    }

    func markDelivered(id: String) {
        var items = load()
        if let index = items.firstIndex(where: { $0.id == id }) {
            if items[index].deliveredAt == nil {
                items[index].deliveredAt = Date()
                save(items)
            }
            return
        }
    }

    func mergeDeliveredNotifications(_ delivered: [NotificationHistoryItem]) {
        var items = load()
        for deliveredItem in delivered {
            if let index = items.firstIndex(where: { $0.id == deliveredItem.id }) {
                if items[index].deliveredAt == nil {
                    items[index].deliveredAt = deliveredItem.deliveredAt ?? Date()
                }
            } else {
                items.insert(deliveredItem, at: 0)
            }
        }
        save(items)
    }
}
