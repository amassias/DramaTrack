import Foundation
import UserNotifications

class NotificationManager {
    static let shared = NotificationManager()

    private let notificationCenter = UNUserNotificationCenter.current()
    private let enabledSlugsKey = "mdl_enabled_notifications"

    // MARK: - Public Methods

    func requestPermission() async -> Bool {
        do {
            return try await notificationCenter.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    func isPermissionGranted() async -> Bool {
        let settings = await notificationCenter.notificationSettings()
        return settings.authorizationStatus == .authorized
    }

    func scheduleNotification(for drama: Drama, episode: Episode) async -> Bool {
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

        // Calculate notification time: 9:00 AM on air date
        var components = Calendar.current.dateComponents([.year, .month, .day], from: airDate)
        components.hour = 9
        components.minute = 0
        components.second = 0

        guard let notificationTime = Calendar.current.date(from: components) else {
            return false
        }

        // Only schedule if time is in future
        if notificationTime <= now {
            return false
        }

        let content = UNMutableNotificationContent()
        content.title = drama.title
        content.body = "Episode \(episode.number) airs today!"
        content.sound = .default
        content.badge = NSNumber(value: UIApplication.shared.applicationIconBadgeNumber + 1)

        // Add custom data
        content.userInfo = [
            "dramaSlug": drama.slug,
            "episodeNumber": episode.number,
            "dramaURL": drama.url ?? ""
        ]

        // Calculate trigger delay
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: notificationTime),
            repeats: false
        )

        let identifier = "next-\(drama.slug)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        do {
            try await notificationCenter.add(request)

            // Save enabled notification
            markNotificationEnabled(slug: drama.slug, episode: episode, airDate: airDate)

            return true
        } catch {
            return false
        }
    }

    func cancelNotification(slug: String) {
        let identifier = "next-\(slug)"
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [identifier])
        markNotificationDisabled(slug: slug)
    }

    func isNotificationEnabled(slug: String) -> Bool {
        let enabledSlugs = getEnabledSlugs()
        return enabledSlugs.contains(slug)
    }

    func getScheduledNotifications() -> [String: [String: Any]] {
        return UserDefaults.standard.dictionary(forKey: enabledSlugsKey) as? [String: [String: Any]] ?? [:]
    }

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
}
