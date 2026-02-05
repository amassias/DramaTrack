import Foundation

protocol EpisodeProviding {
    func fetchEpisodes(slug: String) async throws -> [Episode]
}

protocol NotificationScheduling {
    func scheduleNotification(for drama: Drama, episode: Episode) async -> Bool
    func cancelNotification(slug: String)
    func isNotificationEnabled(slug: String) -> Bool
}

struct NotificationSyncSummary: Equatable {
    let scheduledCount: Int
    let errorCount: Int
}

struct NotificationSyncService {
    nonisolated static let defaultIncludedStatuses: Set<String> = [
        "Watching",
        "Plan to Watch"
    ]

    let episodeProvider: EpisodeProviding
    let scheduler: NotificationScheduling

    func syncUpcomingNotifications(
        dramas: [Drama],
        windowDays: Int?,
        replaceExisting: Bool,
        maxNotifications: Int,
        includeStatuses: Set<String> = Self.defaultIncludedStatuses
    ) async -> NotificationSyncSummary {
        let now = Date()
        let windowEnd = windowDays.flatMap {
            Calendar.current.date(byAdding: .day, value: $0, to: now)
        }

        let eligible = dramas.filter { includeStatuses.contains($0.status) }

        var scheduled = 0
        var errors = 0

        for drama in eligible {
            if scheduled >= maxNotifications {
                break
            }

            if replaceExisting, scheduler.isNotificationEnabled(slug: drama.slug) {
                scheduler.cancelNotification(slug: drama.slug)
            }

            do {
                let episodes = try await episodeProvider.fetchEpisodes(slug: drama.slug)
                let upcoming = Self.upcomingEpisodes(
                    episodes: episodes,
                    now: now,
                    windowEnd: windowEnd
                )

                for episode in upcoming {
                    if scheduled >= maxNotifications {
                        break
                    }
                    let didSchedule = await scheduler.scheduleNotification(for: drama, episode: episode)
                    if didSchedule {
                        scheduled += 1
                    }
                }
            } catch {
                errors += 1
                continue
            }
        }

        return NotificationSyncSummary(scheduledCount: scheduled, errorCount: errors)
    }

    static func upcomingEpisodes(episodes: [Episode], now: Date, windowEnd: Date?) -> [Episode] {
        let candidates = episodes.compactMap { episode -> Episode? in
            guard let date = episode.airDate else { return nil }
            guard date > now else { return nil }
            if let windowEnd {
                guard date <= windowEnd else { return nil }
            }
            return episode
        }

        let sorted = candidates.sorted { lhs, rhs in
            guard let leftDate = lhs.airDate, let rightDate = rhs.airDate else {
                return lhs.number < rhs.number
            }
            if leftDate != rightDate {
                return leftDate < rightDate
            }
            return lhs.number < rhs.number
        }

        return deduplicateByDay(sorted)
    }

    private static func deduplicateByDay(_ episodes: [Episode]) -> [Episode] {
        var seenDays: Set<Date> = []
        var result: [Episode] = []

        for episode in episodes {
            guard let date = episode.airDate else { continue }
            let day = Calendar.current.startOfDay(for: date)
            if seenDays.contains(day) { continue }
            seenDays.insert(day)
            result.append(episode)
        }

        return result
    }
}
