import SwiftUI

struct SettingsView: View {
    let username: String
    let onLogout: () -> Void
    var onSelectDrama: ((Drama) -> Void)?

    @StateObject private var viewModel = SettingsViewModel()
    @EnvironmentObject private var appState: AppState
    @State private var showEditUsername = false
    @State private var newUsername: String = ""
    @State private var editError: String = ""
    @State private var isValidating = false
    @State private var notificationTime = Date()
    @State private var showNotificationTimePicker = false
    @State private var cacheMessage: String = ""
    @State private var statusToggles: [String: Bool] = [:]
    @State private var quietHoursEnabled = true
    @State private var quietStartTime = Date()
    @State private var quietEndTime = Date()

    // Utiliser le watchlistViewModel partagé au lieu de charger à nouveau
    private var dramaList: [Drama] {
        appState.watchlistViewModel.dramas
    }

    private let statusOptions = [
        "Watching",
        "Plan to Watch",
        "On-Hold",
        "Completed",
        "Dropped"
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header with Icon - aligned with Watchlist
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .center, spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 8) {
                                Image(systemName: "gearshape.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(Color(red: 0.86, green: 0.5, blue: 1.0))
                                Text("Settings")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            Text("Manage your account")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        
                        Spacer()
                    }
                }
                .padding(.horizontal, 16)

                // User Card
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(Color(red: 0.86, green: 0.5, blue: 1.0))

                        VStack(alignment: .leading, spacing: 4) {
                            // Use verbatim to avoid localized interpolation warnings
                            Text(verbatim: "@\(username)")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                            Text("MyDramaList Account")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }

                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(12)
                .background(Color.white.opacity(0.05))
                .cornerRadius(8)
                .padding(.horizontal, 16)

                Button(action: {
                    newUsername = username
                    showEditUsername = true
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "pencil")
                        Text("Change Username")
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(red: 0.86, green: 0.5, blue: 1.0))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(8)
                }
                .padding(.horizontal, 16)

                // Notification Preferences
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "bell.badge.fill")
                            .font(.system(size: 16))
                            .foregroundColor(Color(red: 0.86, green: 0.5, blue: 1.0))
                        Text("Notification Preferences")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }

                    Text("Choose which drama statuses can trigger notifications.")
                        .font(.caption)
                        .foregroundColor(.gray)

                    VStack(spacing: 8) {
                        ForEach(statusOptions, id: \.self) { status in
                            Toggle(isOn: Binding(
                                get: { statusToggles[status] ?? false },
                                set: { newValue in
                                    statusToggles[status] = newValue
                                    NotificationManager.shared.setEnabledStatus(status, isEnabled: newValue)
                                    Task { await viewModel.syncNotifications(dramas: dramaList) }
                                }
                            )) {
                                Text(status)
                                    .foregroundColor(.white)
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .tint(Color(red: 0.86, green: 0.5, blue: 1.0))
                        }
                    }

                    Divider()
                        .background(Color.white.opacity(0.08))

                    Toggle(isOn: Binding(
                        get: { quietHoursEnabled },
                        set: { newValue in
                            quietHoursEnabled = newValue
                            saveQuietHours()
                        }
                    )) {
                        Text("Enable Quiet Hours")
                            .foregroundColor(.white)
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .tint(Color(red: 0.86, green: 0.5, blue: 1.0))

                    Text("Notifications will be delayed to the next allowed time window.")
                        .font(.caption)
                        .foregroundColor(.gray)

                    VStack(spacing: 12) {
                        HStack {
                            Text("Start")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                            Spacer()
                            DatePicker(
                                "",
                                selection: $quietStartTime,
                                displayedComponents: .hourAndMinute
                            )
                            .labelsHidden()
                            .colorScheme(.dark)
                            .disabled(!quietHoursEnabled)
                            .onChange(of: quietStartTime) { _, _ in
                                saveQuietHours()
                            }
                        }

                        HStack {
                            Text("End")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                            Spacer()
                            DatePicker(
                                "",
                                selection: $quietEndTime,
                                displayedComponents: .hourAndMinute
                            )
                            .labelsHidden()
                            .colorScheme(.dark)
                            .disabled(!quietHoursEnabled)
                            .onChange(of: quietEndTime) { _, _ in
                                saveQuietHours()
                            }
                        }
                    }
                    .padding(12)
                    .background(Color.white.opacity(0.03))
                    .cornerRadius(8)
                }
                .padding(12)
                .background(Color.white.opacity(0.05))
                .cornerRadius(8)
                .padding(.horizontal, 16)

                // Notifications Section
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "bell.fill")
                            .font(.system(size: 16))
                            .foregroundColor(Color(red: 0.86, green: 0.5, blue: 1.0))
                        Text("Scheduled Notifications")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }

                    if viewModel.scheduledNotifications.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "bell.slash.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.gray)
                            Text("No scheduled notifications")
                                .font(.caption)
                                .foregroundColor(.gray)
                            Text("Enable notifications from drama detail pages")
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                    } else {
                        VStack(spacing: 8) {
                            ForEach(sortedNotifications) { notif in
                                ScheduledNotificationRow(
                                    notification: notif,
                                    drama: dramaList.first(where: { $0.slug == notif.slug }),
                                    onSelectDrama: onSelectDrama,
                                    onCancel: { viewModel.cancelNotification(identifier: notif.identifier) }
                                )
                            }
                        }
                    }
                }
                .padding(12)
                .background(Color.white.opacity(0.05))
                .cornerRadius(8)
                .padding(.horizontal, 16)

                // Notification History
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 16))
                            .foregroundColor(Color(red: 0.86, green: 0.5, blue: 1.0))
                        Text("Notification History")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }

                    if viewModel.notificationHistory.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "clock")
                                .font(.system(size: 24))
                                .foregroundColor(.gray)
                            Text("No delivered notifications yet")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                    } else {
                        VStack(spacing: 8) {
                            ForEach(historyPreview) { item in
                                NotificationHistoryRow(item: item)
                            }
                        }
                    }
                }
                .padding(12)
                .background(Color.white.opacity(0.05))
                .cornerRadius(8)
                .padding(.horizontal, 16)

                // Notification Time Setting
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 16))
                            .foregroundColor(Color(red: 0.86, green: 0.5, blue: 1.0))
                        Text("Notification Time")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    
                    Text("Choose when you want to be notified on episode air dates")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Button(action: {
                        showNotificationTimePicker.toggle()
                    }) {
                        HStack {
                            Text("Notify me at")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                            
                            Spacer()
                            
                            let (hour, minute) = NotificationManager.shared.getNotificationTime()
                            Text(String(format: "%02d:%02d", hour, minute))
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                            
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                        }
                        .padding(12)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(8)
                    }
                    
                    if showNotificationTimePicker {
                        VStack(spacing: 12) {
                            DatePicker(
                                "Time",
                                selection: $notificationTime,
                                displayedComponents: .hourAndMinute
                            )
                            .datePickerStyle(.wheel)
                            .labelsHidden()
                            .colorScheme(.dark)
                            
                            Button(action: {
                                let components = Calendar.current.dateComponents([.hour, .minute], from: notificationTime)
                                if let hour = components.hour, let minute = components.minute {
                                    NotificationManager.shared.setNotificationTime(hour: hour, minute: minute)
                                    Task { await viewModel.syncNotifications(dramas: dramaList) }
                                    showNotificationTimePicker = false
                                }
                            }) {
                                Text("Save Time")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(Color(red: 0.86, green: 0.5, blue: 1.0))
                                    .cornerRadius(8)
                            }
                        }
                        .padding(12)
                        .background(Color.white.opacity(0.03))
                        .cornerRadius(8)
                    }
                }
                .padding(12)
                .background(Color.white.opacity(0.05))
                .cornerRadius(8)
                .padding(.horizontal, 16)

                // Cache Management
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "externaldrive.fill")
                            .font(.system(size: 16))
                            .foregroundColor(Color(red: 0.86, green: 0.5, blue: 1.0))
                        Text("Cache Management")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }

                    Button(action: {
                        ImageCache.shared.clear()
                        cacheMessage = "Image cache cleared."
                    }) {
                        Text("Clear Image Cache")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(8)
                    }

                    Button(action: {
                        appState.watchlistViewModel.clearDetailsCache()
                        cacheMessage = "Details cache cleared."
                    }) {
                        Text("Clear Details Cache")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(8)
                    }

                    Button(action: {
                        ImageCache.shared.clear()
                        appState.watchlistViewModel.clearDetailsCache()
                        appState.watchlistViewModel.clearWatchlistCache()
                        cacheMessage = "All caches cleared."
                    }) {
                        Text("Clear All Caches")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(8)
                    }

                    if !cacheMessage.isEmpty {
                        Text(cacheMessage)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                .padding(12)
                .background(Color.white.opacity(0.05))
                .cornerRadius(8)
                .padding(.horizontal, 16)

                // Logout button
                Button(action: onLogout) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.right.square.fill")
                        Text("Logout")
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
                }
                .padding(.horizontal, 16)

                // Footer
                VStack(spacing: 4) {
                    Text("DramaTrack iOS v1.0")
                        .font(.caption2)
                        .foregroundColor(.gray)
                    Text("Data from MyDramaList Unofficial API")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)

                Spacer(minLength: 80)
            }
        }
        .onAppear {
            Task { await viewModel.loadScheduledNotifications() }
            // Load saved notification time
            let (hour, minute) = NotificationManager.shared.getNotificationTime()
            var components = DateComponents()
            components.hour = hour
            components.minute = minute
            if let date = Calendar.current.date(from: components) {
                notificationTime = date
            }

            let enabledStatuses = NotificationManager.shared.getEnabledStatuses()
            var statusMap: [String: Bool] = [:]
            for status in statusOptions {
                statusMap[status] = enabledStatuses.contains(status)
            }
            statusToggles = statusMap

            let quiet = NotificationManager.shared.getQuietHours()
            quietHoursEnabled = quiet.enabled
            var startComponents = DateComponents()
            startComponents.hour = quiet.start.hour
            startComponents.minute = quiet.start.minute
            if let date = Calendar.current.date(from: startComponents) {
                quietStartTime = date
            }

            var endComponents = DateComponents()
            endComponents.hour = quiet.end.hour
            endComponents.minute = quiet.end.minute
            if let date = Calendar.current.date(from: endComponents) {
                quietEndTime = date
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NotificationManager.didUpdateNotifications)) { _ in
            Task {
                await viewModel.loadScheduledNotifications()
                await viewModel.loadNotificationHistory()
            }
        }
        .sheet(isPresented: $showEditUsername) {
            EditUsernameSheet(
                username: $newUsername,
                error: $editError,
                isValidating: $isValidating,
                onSave: handleSaveUsername,
                onCancel: {
                    showEditUsername = false
                    editError = ""
                }
            )
        }
    }
    
    private func handleSaveUsername() {
        let trimmed = newUsername.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmed.isEmpty else {
            editError = "Username cannot be empty"
            return
        }
        
        // Validate username exists on MyDramaList
        Task {
            isValidating = true
            editError = ""
            
            do {
                let isValid = try await validateUsername(trimmed)
                
                await MainActor.run {
                    isValidating = false
                    
                    if isValid {
                        // Update username with real-time propagation
                        Task {
                            await appState.updateUsername(trimmed)
                            showEditUsername = false
                        }
                    } else {
                        editError = "Username not found on MyDramaList"
                    }
                }
            } catch {
                await MainActor.run {
                    isValidating = false
                    editError = "Unable to verify username. Please check your connection."
                }
            }
        }
    }
    
    private func validateUsername(_ username: String) async throws -> Bool {
        try await APIClient.shared.validateUsername(username)
    }

    private var sortedNotifications: [ScheduledNotification] {
        viewModel.scheduledNotifications.sorted { lhs, rhs in
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

    private var historyPreview: [NotificationHistoryItem] {
        Array(viewModel.notificationHistory.prefix(50))
    }

    private func saveQuietHours() {
        let startComponents = Calendar.current.dateComponents([.hour, .minute], from: quietStartTime)
        let endComponents = Calendar.current.dateComponents([.hour, .minute], from: quietEndTime)

        let start = (startComponents.hour ?? 23, startComponents.minute ?? 0)
        let end = (endComponents.hour ?? 7, endComponents.minute ?? 0)

        NotificationManager.shared.setQuietHours(enabled: quietHoursEnabled, start: start, end: end)
        Task { await viewModel.syncNotifications(dramas: dramaList) }
    }

}

struct EditUsernameSheet: View {
    @Binding var username: String
    @Binding var error: String
    @Binding var isValidating: Bool
    let onSave: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.06, green: 0.04, blue: 0.1),
                    Color(red: 0.1, green: 0.06, blue: 0.15)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 24) {
                Text("Change Username")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("MyDramaList Username")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.gray)
                    
                    HStack(spacing: 12) {
                        Image(systemName: "at")
                            .foregroundColor(.gray)
                        
                        TextField("username", text: $username)
                            .foregroundColor(.white)
                            .textFieldStyle(.plain)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .disabled(isValidating)
                            .onChange(of: username) { _, _ in
                                error = ""
                            }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(12)
                    
                    if !error.isEmpty {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                
                HStack(spacing: 12) {
                    Button(action: onCancel) {
                        Text("Cancel")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.gray)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(12)
                    }
                    .disabled(isValidating)
                    
                    Button(action: onSave) {
                        HStack {
                            if isValidating {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                                Text("Validating...")
                                    .font(.system(size: 16, weight: .semibold))
                            } else {
                                Text("Save")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            username.isEmpty || isValidating
                            ? Color.gray.opacity(0.3)
                            : Color(red: 0.86, green: 0.5, blue: 1.0)
                        )
                        .cornerRadius(12)
                    }
                    .disabled(username.isEmpty || isValidating)
                }
            }
            .padding(24)
        }
    }

}

struct ScheduledNotificationRow: View {
    let notification: ScheduledNotification
    let drama: Drama?
    let onSelectDrama: ((Drama) -> Void)?
    let onCancel: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: {
                if let drama = drama {
                    onSelectDrama?(drama)
                }
            }) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(drama?.title ?? notification.title)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .lineLimit(1)

                        let episodeString = notification.episodeNumber.map(String.init) ?? "?"
                        Text(verbatim: "Episode \(episodeString)")
                            .font(.caption2)
                            .foregroundColor(Color(red: 0.86, green: 0.5, blue: 1.0))

                        Text(formattedAirDate(notification.airDate))
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }

                    Spacer()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .disabled(onSelectDrama == nil || drama == nil)

            Button(action: onCancel) {
                Image(systemName: "trash.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.red)
                    .frame(width: 32, height: 32)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(6)
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .background(Color.white.opacity(0.05))
        .cornerRadius(6)
    }

    private func formattedAirDate(_ date: Date?) -> String {
        guard let date else { return "TBA" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

struct NotificationHistoryRow: View {
    let item: NotificationHistoryItem

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)

                let episodeString = item.episodeNumber.map(String.init) ?? "?"
                Text(verbatim: "Episode \(episodeString)")
                    .font(.caption2)
                    .foregroundColor(Color(red: 0.86, green: 0.5, blue: 1.0))

                Text(formattedDate(item.deliveredAt ?? item.scheduledAt))
                    .font(.caption2)
                    .foregroundColor(.gray)
            }

            Spacer()
        }
        .padding(10)
        .background(Color.white.opacity(0.05))
        .cornerRadius(6)
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

#Preview {
    SettingsView(username: "DoctorIceCream", onLogout: { })
        .environmentObject(AppState())
}
