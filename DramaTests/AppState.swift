import Foundation
import Combine

@MainActor
class AppState: ObservableObject {
    @Published var username: String?
    @Published var isLoading = false
    @Published var error: String?

    private let usernameKey = "mdl_username"
    private let apiClient = APIClient.shared

    init() {
        loadUsername()
    }

    func loadUsername() {
        username = UserDefaults.standard.string(forKey: usernameKey)
        if username == nil {
            username = "DoctorIceCream"
            saveUsername("DoctorIceCream")
        }
    }

    func saveUsername(_ newUsername: String) {
        username = newUsername
        UserDefaults.standard.set(newUsername, forKey: usernameKey)
    }

    func clearUsername() {
        username = nil
        UserDefaults.standard.removeObject(forKey: usernameKey)
    }
}

@MainActor
class WatchlistViewModel: ObservableObject {
    @Published var dramas: [Drama] = []
    @Published var isLoading = false
    @Published var error: String?
    @Published var selectedStatus: DramaStatus = .all
    @Published var searchText: String = ""

    private let apiClient = APIClient.shared

    var filteredDramas: [Drama] {
        var result = dramas

        // Apply status filter
        if selectedStatus != .all {
            result = result.filter { $0.status == selectedStatus.rawValue }
        }

        // Apply search filter
        if !searchText.isEmpty {
            result = result.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
        }

        return result.sorted { $0.title < $1.title }
    }

    var statusCounts: [String: Int] {
        var counts: [String: Int] = [:]
        for drama in dramas {
            counts[drama.status, default: 0] += 1
        }
        return counts
    }

    func fetchWatchlist(username: String) async {
        await MainActor.run { self.isLoading = true; self.error = nil }

        do {
            let response = try await apiClient.fetchWatchlist(username: username)
            await MainActor.run {
                self.dramas = response.dramas
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                self.isLoading = false
            }
        }
    }
}

@MainActor
class DramaDetailViewModel: ObservableObject {
    @Published var episodes: [Episode] = []
    @Published var isLoading = false
    @Published var error: String?
    @Published var notificationEnabled = false
    @Published var nextUpcomingEpisode: Episode?

    private let apiClient = APIClient.shared
    private let notificationManager = NotificationManager.shared
    private let drama: Drama

    init(drama: Drama) {
        self.drama = drama
    }

    func loadEpisodes() async {
        await MainActor.run { self.isLoading = true; self.error = nil }

        do {
            let fetchedEpisodes = try await apiClient.fetchEpisodes(slug: drama.slug)
            await MainActor.run {
                self.episodes = fetchedEpisodes.sorted { $0.number < $1.number }
                self.updateNextUpcomingEpisode()
                self.notificationEnabled = notificationManager.isNotificationEnabled(slug: drama.slug)
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                self.isLoading = false
            }
        }
    }

    func toggleNotification() async {
        if notificationEnabled {
            // Disable notification
            notificationManager.cancelNotification(slug: drama.slug)
            await MainActor.run { self.notificationEnabled = false }
        } else {
            // Enable notification
            guard let nextEpisode = nextUpcomingEpisode else {
                await MainActor.run {
                    self.error = "No upcoming episodes to notify"
                }
                return
            }

            let hasPermission = await notificationManager.isPermissionGranted()
            if !hasPermission {
                let granted = await notificationManager.requestPermission()
                if !granted {
                    await MainActor.run {
                        self.error = "Notification permission denied"
                    }
                    return
                }
            }

            let success = await notificationManager.scheduleNotification(for: drama, episode: nextEpisode)
            await MainActor.run {
                if success {
                    self.notificationEnabled = true
                } else {
                    self.error = "Failed to schedule notification"
                }
            }
        }
    }

    private func updateNextUpcomingEpisode() {
        nextUpcomingEpisode = episodes.first { $0.isUpcoming }
    }

    var upcomingCount: Int {
        episodes.filter { $0.isUpcoming }.count
    }
}

@MainActor
class SettingsViewModel: ObservableObject {
    @Published var scheduledNotifications: [String: [String: Any]] = [:]
    @Published var isRefreshing = false

    private let notificationManager = NotificationManager.shared
    private let apiClient = APIClient.shared

    init() {
        loadScheduledNotifications()
    }

    func loadScheduledNotifications() {
        scheduledNotifications = notificationManager.getScheduledNotifications()
    }

    func cancelNotification(slug: String) {
        notificationManager.cancelNotification(slug: slug)
        loadScheduledNotifications()
    }

    func syncNotifications(dramas: [Drama]) async {
        await MainActor.run { self.isRefreshing = true }

        for drama in dramas where drama.status == "Watching" {
            do {
                let episodes = try await apiClient.fetchEpisodes(slug: drama.slug)
                if let nextEpisode = episodes.first(where: { $0.isUpcoming }) {
                    if !notificationManager.isNotificationEnabled(slug: drama.slug) {
                        _ = await notificationManager.scheduleNotification(for: drama, episode: nextEpisode)
                    }
                }
            } catch {
                // Continue syncing other dramas
                continue
            }
        }

        await MainActor.run {
            self.loadScheduledNotifications()
            self.isRefreshing = false
        }
    }
}
