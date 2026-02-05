import Foundation
import SwiftUI
import Combine

enum SmartListType: CaseIterable {
    case airingWeek
    case onHoldAged
    case dropped
    case completedRecent

    var title: String {
        switch self {
        case .airingWeek: return "Airing in the Next 7 Days"
        case .onHoldAged: return "On-Hold > 30 Days"
        case .dropped: return "Dropped"
        case .completedRecent: return "Completed Recently"
        }
    }

    var subtitle: String {
        switch self {
        case .airingWeek: return "Upcoming episodes within 7 days"
        case .onHoldAged: return "Paused for more than 30 days"
        case .dropped: return "Shows you dropped"
        case .completedRecent: return "Completed in the last 30 days"
        }
    }

    var icon: String {
        switch self {
        case .airingWeek: return "calendar"
        case .onHoldAged: return "pause.circle"
        case .dropped: return "xmark.circle"
        case .completedRecent: return "checkmark.circle"
        }
    }
}

extension SmartListType: Identifiable {
    var id: String {
        switch self {
        case .airingWeek: return "airingWeek"
        case .onHoldAged: return "onHoldAged"
        case .dropped: return "dropped"
        case .completedRecent: return "completedRecent"
        }
    }
}

struct SmartListSummary: Identifiable {
    let id = UUID()
    let type: SmartListType
    let title: String
    let subtitle: String
    let count: Int
}

@MainActor
final class SmartListsViewModel: ObservableObject {
    @Published var lists: [SmartListSummary] = []
    @Published var listItems: [SmartListType: [Drama]] = [:]
    @Published var isLoading = false

    private let apiClient = APIClient.shared
    private let statusHistory = StatusHistoryStore.shared
    private let airingCache = SmartListAiringCache.shared

    func load(dramas: [Drama]) async {
        isLoading = true

        let airingDramas = await buildAiringList(dramas: dramas)
        let onHoldAged = buildOnHoldAged(dramas: dramas)
        let dropped = dramas.filter { $0.status == "Dropped" }
        let completedRecent = buildCompletedRecent(dramas: dramas)

        listItems = [
            .airingWeek: airingDramas,
            .onHoldAged: onHoldAged,
            .dropped: dropped,
            .completedRecent: completedRecent
        ]

        lists = [
            SmartListSummary(type: .airingWeek, title: SmartListType.airingWeek.title, subtitle: SmartListType.airingWeek.subtitle, count: airingDramas.count),
            SmartListSummary(type: .onHoldAged, title: SmartListType.onHoldAged.title, subtitle: SmartListType.onHoldAged.subtitle, count: onHoldAged.count),
            SmartListSummary(type: .dropped, title: SmartListType.dropped.title, subtitle: SmartListType.dropped.subtitle, count: dropped.count),
            SmartListSummary(type: .completedRecent, title: SmartListType.completedRecent.title, subtitle: SmartListType.completedRecent.subtitle, count: completedRecent.count)
        ]

        isLoading = false
    }

    func dramas(for type: SmartListType) -> [Drama] {
        listItems[type] ?? []
    }

    private func buildOnHoldAged(dramas: [Drama]) -> [Drama] {
        let threshold = Date().addingTimeInterval(-30 * 24 * 60 * 60)
        return dramas.filter { drama in
            guard drama.status == "On-Hold" else { return false }
            guard let history = statusHistory.history(for: drama.slug) else { return false }
            return history.updatedAt <= threshold
        }
    }

    private func buildCompletedRecent(dramas: [Drama]) -> [Drama] {
        let threshold = Date().addingTimeInterval(-30 * 24 * 60 * 60)
        return dramas.filter { drama in
            guard drama.status == "Completed" else { return false }
            guard let history = statusHistory.history(for: drama.slug) else { return false }
            return history.updatedAt >= threshold
        }
    }

    private func buildAiringList(dramas: [Drama]) async -> [Drama] {
        let now = Date()
        let windowEnd = Calendar.current.date(byAdding: .day, value: 7, to: now) ?? now

        let candidates = dramas.filter { drama in
            drama.status == "Watching" || drama.status == "Plan to Watch"
        }

        var result: [Drama] = []

        for drama in candidates {
            if let cached = airingCache.getEpisodes(for: drama.slug) {
                if hasUpcomingEpisode(in: cached, now: now, windowEnd: windowEnd) {
                    result.append(drama)
                }
                continue
            }

            do {
                let episodes = try await apiClient.fetchEpisodes(slug: drama.slug)
                let normalized = episodes.compactMap { ep -> AiringEpisode? in
                    guard let date = ep.airDate else { return nil }
                    return AiringEpisode(number: ep.number, airDate: date)
                }
                airingCache.setEpisodes(normalized, for: drama.slug)

                if hasUpcomingEpisode(in: normalized, now: now, windowEnd: windowEnd) {
                    result.append(drama)
                }
            } catch {
                continue
            }
        }

        return result
    }

    private func hasUpcomingEpisode(in episodes: [AiringEpisode], now: Date, windowEnd: Date) -> Bool {
        episodes.contains { episode in
            episode.airDate >= now && episode.airDate <= windowEnd
        }
    }
}
