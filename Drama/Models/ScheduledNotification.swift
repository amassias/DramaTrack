import Foundation

struct ScheduledNotification: Identifiable, Hashable {
    let identifier: String
    let slug: String
    let title: String
    let episodeNumber: Int?
    let airDate: Date?
    let dramaURL: String?

    var id: String { identifier }
}
