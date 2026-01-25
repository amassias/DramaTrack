import SwiftUI

struct RootView: View {
    @StateObject private var appState = AppState()
    @State private var currentTab: Tab = .watchlist
    @State private var selectedDrama: Drama?

    enum Tab {
        case watchlist
        case detail
        case settings
    }

    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.06, green: 0.04, blue: 0.1),
                    Color(red: 0.1, green: 0.06, blue: 0.15)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Group {
                if let username = appState.username {
                    mainContent(username: username)
                } else {
                    VStack {
                        Text("Loading...")
                            .foregroundColor(.white)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func mainContent(username: String) -> some View {
        ZStack {
            Group {
                switch currentTab {
                case .watchlist:
                    WatchlistView(username: username) { drama in
                        selectedDrama = drama
                        currentTab = .detail
                    }

                case .detail:
                    if let drama = selectedDrama {
                        DramaDetailView(drama: drama) {
                            currentTab = .watchlist
                            selectedDrama = nil
                        }
                    }

                case .settings:
                    SettingsView(username: username) {
                        appState.clearUsername()
                    }
                }
            }

            // Bottom Tab Bar
            VStack {
                Spacer()
                BottomTabBar(
                    currentTab: $currentTab,
                    onSelectTab: { tab in
                        currentTab = tab
                    }
                )
            }
        }
    }
}

struct BottomTabBar: View {
    @Binding var currentTab: RootView.Tab
    let onSelectTab: (RootView.Tab) -> Void

    var body: some View {
        HStack(spacing: 0) {
            TabBarItem(
                icon: "tv.fill",
                title: "Watchlist",
                isActive: currentTab == .watchlist,
                action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        currentTab = .watchlist
                    }
                }
            )

            Spacer()

            TabBarItem(
                icon: "gear.fill",
                title: "Settings",
                isActive: currentTab == .settings,
                action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        currentTab = .settings
                    }
                }
            )
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(
            Color.black.opacity(0.5)
                .blur(radius: 10)
        )
        .frame(height: 60)
    }
}

struct TabBarItem: View {
    let icon: String
    let title: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                Text(title)
                    .font(.caption2)
                    .fontWeight(.medium)
            }
            .foregroundColor(isActive ? Color(red: 0.86, green: 0.5, blue: 1.0) : Color(red: 0.6, green: 0.6, blue: 0.6))
            .frame(maxWidth: .infinity)
        }
    }
}

#Preview {
    RootView()
}
