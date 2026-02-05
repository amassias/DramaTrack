import Foundation
import UserNotifications
import UIKit
#if canImport(BackgroundTasks)
import BackgroundTasks
#endif

class NotificationManager {
    static let shared = NotificationManager()
    static let didUpdateNotifications = Notification.Name("NotificationManager.didUpdateNotifications")

    private let notificationCenter = UNUserNotificationCenter.current()
    private let enabledSlugsKey = "mdl_enabled_notifications"
    private let notificationTimeKey = "mdl_notification_time"
    private let enabledStatusesKey = "mdl_notification_statuses_enabled"
    private let quietHoursEnabledKey = "mdl_quiet_hours_enabled"
    private let quietHoursStartKey = "mdl_quiet_hours_start"
    private let quietHoursEndKey = "mdl_quiet_hours_end"
    private let permissionPromptedKey = "mdl_notifications_prompted"
    private let usernameKey = "mdl_username"
    private let backgroundRefreshTaskId = "com.arthurmassias.Drama.refresh"
    private let maxScheduledNotifications = 60

    // MARK: - Public Methods

    func requestPermission() async -> Bool {
        do {
            return try await notificationCenter.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    func requestPermissionIfNeeded() async -> Bool {
        if UserDefaults.standard.bool(forKey: permissionPromptedKey) {
            return await isPermissionGranted()
        }

        UserDefaults.standard.set(true, forKey: permissionPromptedKey)
        return await requestPermission()
    }

    func isPermissionGranted() async -> Bool {
        let settings = await notificationCenter.notificationSettings()
        return settings.authorizationStatus == .authorized
    }

    func scheduleNotification(for drama: Drama, episode: Episode) async -> Bool {
        guard getEnabledStatuses().contains(drama.status) else {
            return false
        }

        // Check permission
        let hasPermission = await isPermissionGranted()
        if !hasPermission {
            let granted = await requestPermission()
            if !granted {
                return false
            }
        }

        guard let airDate = episode.airDate else {
            return false
        }

        // Check if air date is in the future
        let now = Date()
        if airDate <= now {
            return false
        }

        // Calculate notification time using user preference
        let preferredTime = getNotificationTime()
        var components = Calendar.current.dateComponents([.year, .month, .day], from: airDate)
        components.hour = preferredTime.hour
        components.minute = preferredTime.minute
        components.second = 0

        guard let notificationTime = Calendar.current.date(from: components) else {
            return false
        }

        let adjustedTime = applyQuietHours(to: notificationTime)

        // Only schedule if time is in future
        if adjustedTime <= now {
            return false
        }

        let content = UNMutableNotificationContent()
        content.title = drama.title
        content.body = "Episode \(episode.number) airs today!"
        content.sound = .default

        // Set a badge count using modern API on iOS 17+
        let badgeCount = 1
        if #available(iOS 17.0, *) {
            do {
                try await notificationCenter.setBadgeCount(badgeCount)
            } catch {
                // Optional: log or ignore; content.badge still applies when delivered
            }
        }
        content.badge = NSNumber(value: badgeCount)

        // Add custom data
        content.userInfo = [
            "dramaSlug": drama.slug,
            "episodeNumber": episode.number,
            "dramaURL": drama.url ?? "",
            "airDate": airDate
        ]

        // Calculate trigger
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: adjustedTime),
            repeats: false
        )

        let identifier = notificationIdentifier(slug: drama.slug, episode: episode)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        do {
            try await notificationCenter.add(request)

            // Save enabled notification
            markNotificationEnabled(slug: drama.slug, episode: episode, airDate: airDate)
            NotificationHistoryStore.shared.upsertScheduled(
                id: identifier,
                slug: drama.slug,
                title: drama.title,
                episodeNumber: episode.number,
                airDate: airDate
            )

            return true
        } catch {
            return false
        }
    }

    // Optional: reset badge to zero on iOS 17+ without deprecated APIs
    func resetBadgeCount() {
        if #available(iOS 17.0, *) {
            Task {
                do {
                    try await UNUserNotificationCenter.current().setBadgeCount(0)
                } catch {
                    print("Failed to reset badge: \(error)")
                }
            }
        } else {
            // No non-deprecated API for earlier iOS; skip to avoid warnings.
        }
    }

    func cancelNotification(slug: String) {
        Task {
            let requests = await notificationCenter.pendingNotificationRequests()
            let identifiers = requests
                .filter { ($0.content.userInfo["dramaSlug"] as? String) == slug }
                .map { $0.identifier }
            notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiers)
            markNotificationDisabled(slug: slug)
        }
    }

    func cancelNotification(identifier: String) {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [identifier])
    }

    func isNotificationEnabled(slug: String) -> Bool {
        let enabledSlugs = getEnabledSlugs()
        return enabledSlugs.contains(slug)
    }

    func getScheduledNotifications() -> [String: [String: Any]] {
        return UserDefaults.standard.dictionary(forKey: enabledSlugsKey) as? [String: [String: Any]] ?? [:]
    }

    func getPendingScheduledNotifications() async -> [ScheduledNotification] {
        let requests = await notificationCenter.pendingNotificationRequests()
        let items: [ScheduledNotification] = requests.compactMap { request in
            let userInfo = request.content.userInfo
            guard let slug = userInfo["dramaSlug"] as? String else { return nil }
            let title = request.content.title
            let episodeNumber = userInfo["episodeNumber"] as? Int
            let airDate = userInfo["airDate"] as? Date
            let url = userInfo["dramaURL"] as? String
            return ScheduledNotification(
                identifier: request.identifier,
                slug: slug,
                title: title,
                episodeNumber: episodeNumber,
                airDate: airDate,
                dramaURL: url
            )
        }

        return items.sorted { lhs, rhs in
            switch (lhs.airDate, rhs.airDate) {
            case let (.some(a), .some(b)):
                return a < b
            case (.some, .none):
                return true
            case (.none, .some):
                return false
            default:
                return lhs.slug < rhs.slug
            }
        }
    }

    func refreshHistoryFromDeliveredNotifications() async {
        let delivered = await notificationCenter.deliveredNotifications()
        let items: [NotificationHistoryItem] = delivered.compactMap { notif in
            let userInfo = notif.request.content.userInfo
            guard let slug = userInfo["dramaSlug"] as? String else { return nil }
            let title = notif.request.content.title
            let episodeNumber = userInfo["episodeNumber"] as? Int
            let airDate = userInfo["airDate"] as? Date
            return NotificationHistoryItem(
                id: notif.request.identifier,
                slug: slug,
                title: title,
                episodeNumber: episodeNumber,
                airDate: airDate,
                scheduledAt: Date(),
                deliveredAt: Date()
            )
        }
        NotificationHistoryStore.shared.mergeDeliveredNotifications(items)
    }

    func syncUpcomingNotifications(
        dramas: [Drama],
        windowDays: Int?,
        replaceExisting: Bool,
        includeStatuses: Set<String>? = nil
    ) async -> NotificationSyncSummary {
        let hasPermission = await isPermissionGranted()
        guard hasPermission else {
            return NotificationSyncSummary(scheduledCount: 0, errorCount: 0)
        }

        let statuses = includeStatuses ?? getEnabledStatuses()
        let service = NotificationSyncService(episodeProvider: APIClient.shared, scheduler: self)
        let summary = await service.syncUpcomingNotifications(
            dramas: dramas,
            windowDays: windowDays,
            replaceExisting: replaceExisting,
            maxNotifications: maxScheduledNotifications,
            includeStatuses: statuses
        )

        NotificationCenter.default.post(name: NotificationManager.didUpdateNotifications, object: nil)
        return summary
    }

    func resyncUsingCurrentSettings(dramas: [Drama], windowDays: Int? = nil, replaceExisting: Bool = true) async -> NotificationSyncSummary {
        let statuses = getEnabledStatuses()
        return await syncUpcomingNotifications(
            dramas: dramas,
            windowDays: windowDays,
            replaceExisting: replaceExisting,
            includeStatuses: statuses
        )
    }

    // MARK: - Background Refresh

    func registerBackgroundTasks() {
        #if canImport(BackgroundTasks)
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: backgroundRefreshTaskId,
            using: nil
        ) { task in
            guard let refreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            self.handleAppRefresh(task: refreshTask)
        }
        #endif
    }

    func setupNotificationDelegate() {
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
    }

    private final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
        static let shared = NotificationDelegate()

        func userNotificationCenter(
            _ center: UNUserNotificationCenter,
            willPresent notification: UNNotification
        ) async -> UNNotificationPresentationOptions {
            NotificationHistoryStore.shared.markDelivered(id: notification.request.identifier)
            NotificationCenter.default.post(name: NotificationManager.didUpdateNotifications, object: nil)
            return [.banner, .sound, .badge]
        }

        func userNotificationCenter(
            _ center: UNUserNotificationCenter,
            didReceive response: UNNotificationResponse
        ) async {
            NotificationHistoryStore.shared.markDelivered(id: response.notification.request.identifier)
            NotificationCenter.default.post(name: NotificationManager.didUpdateNotifications, object: nil)
        }
    }

    func scheduleBackgroundRefresh() {
        #if canImport(BackgroundTasks)
        let request = BGAppRefreshTaskRequest(identifier: backgroundRefreshTaskId)
        request.earliestBeginDate = Date().addingTimeInterval(12 * 60 * 60)
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("⚠️ Failed to schedule background refresh: \(error)")
        }
        #endif
    }

    #if canImport(BackgroundTasks)
    private func handleAppRefresh(task: BGAppRefreshTask) {
        scheduleBackgroundRefresh()

        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }

        Task {
            guard let username = UserDefaults.standard.string(forKey: usernameKey) else {
                task.setTaskCompleted(success: true)
                return
            }

            do {
                let response = try await APIClient.shared.fetchWatchlist(username: username)
                _ = await self.syncUpcomingNotifications(
                    dramas: response.dramas,
                    windowDays: nil,
                    replaceExisting: true
                )
                task.setTaskCompleted(success: true)
            } catch {
                print("⚠️ Background refresh failed: \(error)")
                task.setTaskCompleted(success: false)
            }
        }
    }
    #endif

    // MARK: - Private Methods

    private func getEnabledSlugs() -> Set<String> {
        let scheduled = getScheduledNotifications()
        return Set(scheduled.keys)
    }

    private func markNotificationEnabled(slug: String, episode: Episode, airDate: Date) {
        var scheduled = getScheduledNotifications()
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium

        scheduled[slug] = [
            "enabled": true,
            "episode": episode.number,
            "airDate": dateFormatter.string(from: airDate),
            "timestamp": Date().timeIntervalSince1970
        ]

        UserDefaults.standard.set(scheduled, forKey: enabledSlugsKey)
    }

    private func markNotificationDisabled(slug: String) {
        var scheduled = getScheduledNotifications()
        scheduled.removeValue(forKey: slug)
        UserDefaults.standard.set(scheduled, forKey: enabledSlugsKey)
    }
    
    // MARK: - Notification Time Preference
    
    func getNotificationTime() -> (hour: Int, minute: Int) {
        if let timeDict = UserDefaults.standard.dictionary(forKey: notificationTimeKey) as? [String: Int],
           let hour = timeDict["hour"],
           let minute = timeDict["minute"] {
            return (hour, minute)
        }
        // Default: 9:00 AM
        return (9, 0)
    }
    
    func setNotificationTime(hour: Int, minute: Int) {
        let timeDict: [String: Int] = ["hour": hour, "minute": minute]
        UserDefaults.standard.set(timeDict, forKey: notificationTimeKey)
    }

    // MARK: - Notification Status Preferences

    func getEnabledStatuses() -> Set<String> {
        let map = getEnabledStatusMap()
        let enabled = map.compactMap { key, value in
            value ? key : nil
        }
        return Set(enabled)
    }

    func setEnabledStatus(_ status: String, isEnabled: Bool) {
        var map = getEnabledStatusMap()
        map[status] = isEnabled
        UserDefaults.standard.set(map, forKey: enabledStatusesKey)
    }

    private func getEnabledStatusMap() -> [String: Bool] {
        if let stored = UserDefaults.standard.dictionary(forKey: enabledStatusesKey) as? [String: Bool] {
            return stored
        }

        return [
            "Watching": true,
            "Plan to Watch": true,
            "On-Hold": false,
            "Completed": false,
            "Dropped": false
        ]
    }

    // MARK: - Quiet Hours Preferences

    func getQuietHours() -> (enabled: Bool, start: (hour: Int, minute: Int), end: (hour: Int, minute: Int)) {
        let enabled = UserDefaults.standard.object(forKey: quietHoursEnabledKey) as? Bool ?? true

        let startDict = UserDefaults.standard.dictionary(forKey: quietHoursStartKey) as? [String: Int]
        let endDict = UserDefaults.standard.dictionary(forKey: quietHoursEndKey) as? [String: Int]

        let startHour = startDict?["hour"] ?? 23
        let startMinute = startDict?["minute"] ?? 0
        let endHour = endDict?["hour"] ?? 7
        let endMinute = endDict?["minute"] ?? 0

        return (enabled, (startHour, startMinute), (endHour, endMinute))
    }

    func setQuietHours(enabled: Bool, start: (hour: Int, minute: Int), end: (hour: Int, minute: Int)) {
        UserDefaults.standard.set(enabled, forKey: quietHoursEnabledKey)
        UserDefaults.standard.set(["hour": start.hour, "minute": start.minute], forKey: quietHoursStartKey)
        UserDefaults.standard.set(["hour": end.hour, "minute": end.minute], forKey: quietHoursEndKey)
    }

    private func applyQuietHours(to date: Date) -> Date {
        let settings = getQuietHours()
        guard settings.enabled else { return date }

        let startMinutes = settings.start.hour * 60 + settings.start.minute
        let endMinutes = settings.end.hour * 60 + settings.end.minute

        guard startMinutes != endMinutes else { return date }

        let calendar = Calendar.current
        let timeComponents = calendar.dateComponents([.hour, .minute], from: date)
        let currentMinutes = (timeComponents.hour ?? 0) * 60 + (timeComponents.minute ?? 0)

        let isOvernight = startMinutes > endMinutes
        let isInQuiet: Bool
        if isOvernight {
            isInQuiet = currentMinutes >= startMinutes || currentMinutes < endMinutes
        } else {
            isInQuiet = currentMinutes >= startMinutes && currentMinutes < endMinutes
        }

        guard isInQuiet else { return date }

        if isOvernight {
            if currentMinutes >= startMinutes {
                return nextDay(at: settings.end, from: date) ?? date
            } else {
                return sameDay(at: settings.end, from: date) ?? date
            }
        } else {
            return sameDay(at: settings.end, from: date) ?? date
        }
    }

    private func sameDay(at time: (hour: Int, minute: Int), from date: Date) -> Date? {
        let calendar = Calendar.current
        return calendar.date(bySettingHour: time.hour, minute: time.minute, second: 0, of: date)
    }

    private func nextDay(at time: (hour: Int, minute: Int), from date: Date) -> Date? {
        let calendar = Calendar.current
        guard let next = calendar.date(byAdding: .day, value: 1, to: date) else { return nil }
        return calendar.date(bySettingHour: time.hour, minute: time.minute, second: 0, of: next)
    }

    private func notificationIdentifier(slug: String, episode: Episode) -> String {
        let timestamp = episode.airDate?.timeIntervalSince1970 ?? Date().timeIntervalSince1970
        return "ep-\(slug)-\(episode.number)-\(Int(timestamp))"
    }
}

extension NotificationManager: NotificationScheduling {}
