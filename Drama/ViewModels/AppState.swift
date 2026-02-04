import Foundation
import Combine

@MainActor
class AppState: ObservableObject {
    @Published var username: String?
    @Published var isLoading = false
    @Published var error: String?
    @Published var hasCompletedOnboarding: Bool = false
    
    // Watchlist ViewModel persistant pour éviter les rechargements
    let watchlistViewModel = WatchlistViewModel()

    private let usernameKey = "mdl_username"
    private let onboardingKey = "mdl_has_completed_onboarding"
    private let apiClient = APIClient.shared
    private var isSyncingNotifications = false

    init() {
        loadUsername()
        loadOnboardingStatus()
    }

    func loadUsername() {
        username = UserDefaults.standard.string(forKey: usernameKey)
        // No longer auto-set default username - let onboarding handle first launch
    }
    
    func loadOnboardingStatus() {
        hasCompletedOnboarding = UserDefaults.standard.bool(forKey: onboardingKey)
    }
    
    func completeOnboarding(username: String) async {
        saveUsername(username)
        hasCompletedOnboarding = true
        UserDefaults.standard.set(true, forKey: onboardingKey)

        _ = await NotificationManager.shared.requestPermissionIfNeeded()
    }
    
    func updateUsername(_ newUsername: String) async {
        // Save new username
        saveUsername(newUsername)
        
        // Reset watchlist to force reload with new username
        self.watchlistViewModel.hasLoadedThisSession = false
        self.watchlistViewModel.dramas = []
        
        await watchlistViewModel.fetchWatchlist(username: newUsername, forceRefresh: true)
    }

    func saveUsername(_ newUsername: String) {
        username = newUsername
        UserDefaults.standard.set(newUsername, forKey: usernameKey)
    }

    func clearUsername() {
        username = nil
        hasCompletedOnboarding = false
        watchlistViewModel.hasLoadedThisSession = false
        watchlistViewModel.dramas = []
        UserDefaults.standard.removeObject(forKey: usernameKey)
        UserDefaults.standard.set(false, forKey: onboardingKey)
    }

    func autoSyncNotificationsIfNeeded() async {
        guard hasCompletedOnboarding else { return }
        guard username != nil else { return }
        guard !watchlistViewModel.dramas.isEmpty else { return }
        guard !isSyncingNotifications else { return }

        let hasPermission = await NotificationManager.shared.isPermissionGranted()
        guard hasPermission else { return }

        isSyncingNotifications = true
        defer { isSyncingNotifications = false }

        _ = await NotificationManager.shared.syncUpcomingNotifications(
            dramas: watchlistViewModel.dramas,
            windowDays: nil,
            replaceExisting: true
        )
    }
}

@MainActor
class WatchlistViewModel: ObservableObject {
    @Published var dramas: [Drama] = []
    @Published var isLoading = false
    @Published var error: String?
    @Published var selectedStatus: DramaStatus = .all
    @Published var searchText: String = ""
    @Published var sortOption: SortOption = .titleAZ
    @Published var prioritizeWatching: Bool = true
    @Published var detailsFetched: Bool = false
    @Published var hasLoadedThisSession: Bool = false
    @Published var isOffline = false
    @Published var serverDown = false

    private let apiClient = APIClient.shared
    private let sortOptionKey = "mdl_sort_option"
    private let prioritizeWatchingKey = "mdl_prioritize_watching"
    private let detailsCacheKey = "mdl_details_cache"
    private let cacheTimestampKey = "mdl_cache_timestamp"
    private let cacheExpiryHours: TimeInterval = 24
    private let watchlistCacheKey = "mdl_watchlist_cache"
    private let watchlistCacheTimestampKey = "mdl_watchlist_cache_timestamp"

    init() {
        loadSortPreferences()
    }
    
    private func loadSortPreferences() {
        if let savedSort = UserDefaults.standard.string(forKey: sortOptionKey),
           let option = SortOption(rawValue: savedSort) {
            sortOption = option
        }
        prioritizeWatching = UserDefaults.standard.bool(forKey: prioritizeWatchingKey)
        // Default to true if never set
        if UserDefaults.standard.object(forKey: prioritizeWatchingKey) == nil {
            prioritizeWatching = true
        }
    }
    
    func saveSortPreferences() {
        UserDefaults.standard.set(sortOption.rawValue, forKey: sortOptionKey)
        UserDefaults.standard.set(prioritizeWatching, forKey: prioritizeWatchingKey)
    }

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

        // Sort based on selected option
        if prioritizeWatching {
            // Partition into "Watching" and others
            let watching = result.filter { $0.status == "Watching" }
            let others = result.filter { $0.status != "Watching" }
            
            // Sort each group
            let sortedWatching = sortDramas(watching)
            let sortedOthers = sortDramas(others)
            
            // Combine with Watching first
            return sortedWatching + sortedOthers
        } else {
            return sortDramas(result)
        }
    }
    
    private func sortDramas(_ dramas: [Drama]) -> [Drama] {
        switch sortOption {
        case .titleAZ:
            return dramas.sorted { $0.title < $1.title }
        case .titleZA:
            return dramas.sorted { $0.title > $1.title }
        case .status:
            return dramas.sorted { drama1, drama2 in
                // Custom status order: Watching > Plan to Watch > On-Hold > Completed > Dropped
                let statusOrder: [String: Int] = [
                    "Watching": 0,
                    "Plan to Watch": 1,
                    "On-Hold": 2,
                    "Completed": 3,
                    "Dropped": 4
                ]
                let order1 = statusOrder[drama1.status] ?? 5
                let order2 = statusOrder[drama2.status] ?? 5
                if order1 != order2 {
                    return order1 < order2
                }
                return drama1.title < drama2.title
            }
        case .ratingHighToLow:
            return dramas.sorted { drama1, drama2 in
                let rating1 = Double(drama1.overallRating ?? "") ?? -1
                let rating2 = Double(drama2.overallRating ?? "") ?? -1
                if rating1 != rating2 {
                    return rating1 > rating2
                }
                return drama1.title < drama2.title
            }
        case .ratingLowToHigh:
            return dramas.sorted { drama1, drama2 in
                let rating1 = Double(drama1.overallRating ?? "") ?? Double.infinity
                let rating2 = Double(drama2.overallRating ?? "") ?? Double.infinity
                if rating1 != rating2 {
                    return rating1 < rating2
                }
                return drama1.title < drama2.title
            }
        }
    }
    
    var hasWatchingDramas: Bool {
        dramas.contains { $0.status == "Watching" }
    }

    var statusCounts: [String: Int] {
        var counts: [String: Int] = [:]
        for drama in dramas {
            counts[drama.status, default: 0] += 1
        }
        return counts
    }

    func fetchWatchlist(username: String, forceRefresh: Bool = false) async {
        await MainActor.run { self.isLoading = true; self.error = nil }

        do {
            let response = try await apiClient.fetchWatchlist(username: username)
            
            // Check if we have valid cached details
            let hasCachedDetails = !forceRefresh && isCacheValid()
            
            await MainActor.run {
                self.dramas = response.dramas
                self.hasLoadedThisSession = true
                self.isOffline = false
                self.serverDown = false
                
                // Apply cached details if available
                if hasCachedDetails {
                    self.applyCachedDetails()
                    print("✅ Loaded \(self.dramas.count) dramas with cached details")
                }
                
                self.isLoading = false
            }

            saveWatchlistCache(response.dramas)
            
            // Fetch ratings and posters in background only if cache is invalid or force refresh
            if !hasCachedDetails {
                await fetchDetailsInBackground()
                await MainActor.run {
                    self.detailsFetched = true
                }
            }
        } catch {
            if let cached = loadWatchlistCache() {
                await MainActor.run {
                    self.dramas = cached
                    self.hasLoadedThisSession = true
                    self.isOffline = true
                    self.serverDown = false
                    self.error = "Offline mode: showing last saved watchlist."
                    self.isLoading = false
                }
            } else {
                await MainActor.run {
                    self.isOffline = false
                    self.serverDown = self.isServerDownError(error)
                    self.error = ErrorMessage.userFacing(error)
                    self.isLoading = false
                }
            }
        }
    }
    
    private func fetchDetailsInBackground() async {
        // Fetch details (ratings + posters) for all dramas in background
        await withTaskGroup(of: (String, String?, String?).self) { group in
            for drama in dramas {
                group.addTask {
                    do {
                        let details = try await self.apiClient.fetchDramaDetails(slug: drama.slug)
                        return (drama.slug, details.rating, details.image)
                    } catch {
                        print("⚠️ Failed to fetch details for \(drama.slug): \(error)")
                        return (drama.slug, nil, nil)
                    }
                }
            }
            
            var detailsMap: [String: (rating: String?, image: String?)] = [:]
            for await (slug, rating, image) in group {
                detailsMap[slug] = (rating: rating, image: image)
            }
            
            await MainActor.run {
                // Update dramas with ratings and images
                self.dramas = self.dramas.map { drama in
                    var updatedDrama = drama
                    if let details = detailsMap[drama.slug] {
                        updatedDrama.overallRating = details.rating
                        // Update image if it's empty or missing
                        if let newImage = details.image, !newImage.isEmpty {
                            updatedDrama = Drama(
                                title: drama.title,
                                slug: drama.slug,
                                status: drama.status,
                                rating: drama.rating,
                                image: newImage,
                                url: drama.url,
                                overallRating: details.rating
                            )
                        }
                    }
                    return updatedDrama
                }
                
                // Save details to cache
                self.saveDetailsToCache(detailsMap)
                print("✅ Fetched and cached details for \(detailsMap.count) dramas")
            }
        }
    }
    
    private func isCacheValid() -> Bool {
        guard let timestamp = UserDefaults.standard.object(forKey: cacheTimestampKey) as? Date else {
            return false
        }
        let hoursSinceCache = Date().timeIntervalSince(timestamp) / 3600
        return hoursSinceCache < cacheExpiryHours
    }
    
    private func saveDetailsToCache(_ detailsMap: [String: (rating: String?, image: String?)]) {
        // Convert to serializable format
        var cache: [String: [String: String]] = [:]
        for (slug, details) in detailsMap {
            var entry: [String: String] = [:]
            if let rating = details.rating {
                entry["rating"] = rating
            }
            if let image = details.image {
                entry["image"] = image
            }
            if !entry.isEmpty {
                cache[slug] = entry
            }
        }
        
        UserDefaults.standard.set(cache, forKey: detailsCacheKey)
        UserDefaults.standard.set(Date(), forKey: cacheTimestampKey)
    }
    
    private func applyCachedDetails() {
        guard let cache = UserDefaults.standard.dictionary(forKey: detailsCacheKey) as? [String: [String: String]] else {
            return
        }
        
        dramas = dramas.map { drama in
            guard let cachedDetails = cache[drama.slug] else {
                return drama
            }
            
            var updatedDrama = drama
            updatedDrama.overallRating = cachedDetails["rating"]
            
            if let cachedImage = cachedDetails["image"], !cachedImage.isEmpty {
                updatedDrama = Drama(
                    title: drama.title,
                    slug: drama.slug,
                    status: drama.status,
                    rating: drama.rating,
                    image: cachedImage,
                    url: drama.url,
                    overallRating: cachedDetails["rating"]
                )
            }
            
            return updatedDrama
        }
    }

    private func saveWatchlistCache(_ dramas: [Drama]) {
        if let data = try? JSONEncoder().encode(dramas) {
            UserDefaults.standard.set(data, forKey: watchlistCacheKey)
            UserDefaults.standard.set(Date(), forKey: watchlistCacheTimestampKey)
        }
    }

    private func loadWatchlistCache() -> [Drama]? {
        guard let data = UserDefaults.standard.data(forKey: watchlistCacheKey) else {
            return nil
        }
        return try? JSONDecoder().decode([Drama].self, from: data)
    }

    func clearDetailsCache() {
        UserDefaults.standard.removeObject(forKey: detailsCacheKey)
        UserDefaults.standard.removeObject(forKey: cacheTimestampKey)
        detailsFetched = false
    }

    func clearWatchlistCache() {
        UserDefaults.standard.removeObject(forKey: watchlistCacheKey)
        UserDefaults.standard.removeObject(forKey: watchlistCacheTimestampKey)
    }

    private func isServerDownError(_ error: Error) -> Bool {
        if let apiError = error as? APIError {
            switch apiError {
            case .serverError, .invalidResponse:
                return true
            default:
                return false
            }
        }
        if let urlError = error as? URLError {
            switch urlError.code {
            case .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
                return true
            default:
                return false
            }
        }
        return false
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
            print("📡 Loading episodes for: \(drama.slug)")
            let fetchedEpisodes = try await apiClient.fetchEpisodes(slug: drama.slug)
            
            await MainActor.run {
                if fetchedEpisodes.isEmpty {
                    print("⚠️ No episodes returned from API for: \(drama.slug)")
                    self.error = "No episode information available"
                } else {
                    print("✅ Successfully loaded \(fetchedEpisodes.count) episodes")
                    self.episodes = fetchedEpisodes.sorted { $0.number < $1.number }
                    self.updateNextUpcomingEpisode()
                    self.error = nil
                }
                self.notificationEnabled = notificationManager.isNotificationEnabled(slug: drama.slug)
                self.isLoading = false
            }
            
            // Auto-enable notifications if not already enabled and upcoming episode exists
            await autoEnableNotificationsIfNeeded()
        } catch {
            await MainActor.run {
                print("❌ Error loading episodes: \(error.localizedDescription)")
                self.error = ErrorMessage.userFacing(error)
                self.isLoading = false
            }
        }
    }

    private func autoEnableNotificationsIfNeeded() async {
        // Only auto-enable if not already enabled
        guard !notificationManager.isNotificationEnabled(slug: drama.slug) else {
            print("✅ Notifications already enabled for: \(drama.slug)")
            return
        }

        // Only auto-enable if there's an upcoming episode
        guard let nextEpisode = nextUpcomingEpisode else {
            print("ℹ️ No upcoming episodes to notify for: \(drama.slug)")
            return
        }

        // Check permission status
        let hasPermission = await notificationManager.isPermissionGranted()
        
        if hasPermission {
            // Permission already granted, schedule notification immediately
            let success = await notificationManager.scheduleNotification(for: drama, episode: nextEpisode)
            await MainActor.run {
                if success {
                    self.notificationEnabled = true
                    print("✅ Auto-enabled notifications for: \(drama.slug)")
                } else {
                    print("⚠️ Failed to auto-enable notifications for: \(drama.slug)")
                }
            }
        } else {
            // Permission not granted yet - request it
            let granted = await notificationManager.requestPermission()
            if granted {
                // Permission was granted, now schedule notification
                let success = await notificationManager.scheduleNotification(for: drama, episode: nextEpisode)
                await MainActor.run {
                    if success {
                        self.notificationEnabled = true
                        print("✅ Auto-enabled notifications for: \(drama.slug)")
                    }
                }
            } else {
                print("ℹ️ Notification permission denied, skipping auto-enable for: \(drama.slug)")
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
    @Published var scheduledNotifications: [ScheduledNotification] = []
    @Published var notificationHistory: [NotificationHistoryItem] = []
    @Published var isRefreshing = false

    private let notificationManager = NotificationManager.shared
    private let apiClient = APIClient.shared

    init() {
        Task {
            await loadScheduledNotifications()
        }
    }

    func loadScheduledNotifications() async {
        let pending = await notificationManager.getPendingScheduledNotifications()
        await MainActor.run {
            self.scheduledNotifications = pending
        }
        await loadNotificationHistory()
    }

    func loadNotificationHistory() async {
        let items = NotificationHistoryStore.shared.load()
        await MainActor.run {
            self.notificationHistory = items
        }
    }

    func cancelNotification(identifier: String) {
        notificationManager.cancelNotification(identifier: identifier)
        Task {
            await loadScheduledNotifications()
        }
    }

    func syncNotifications(dramas: [Drama]) async {
        await MainActor.run { self.isRefreshing = true }

        _ = await notificationManager.syncUpcomingNotifications(
            dramas: dramas,
            windowDays: nil,
            replaceExisting: true
        )

        await MainActor.run {
            self.isRefreshing = false
        }
        await loadScheduledNotifications()
    }
}
