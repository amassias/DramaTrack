import SwiftUI

@main
struct MyDramaApp: App {
    init() {
        NotificationManager.shared.registerBackgroundTasks()
        NotificationManager.shared.scheduleBackgroundRefresh()
        NotificationManager.shared.setupNotificationDelegate()
        Task { await NotificationManager.shared.refreshHistoryFromDeliveredNotifications() }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
