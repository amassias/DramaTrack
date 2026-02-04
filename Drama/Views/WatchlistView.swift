import SwiftUI

struct WatchlistView: View {
    let username: String
    let onSelectDrama: (Drama) -> Void
    @ObservedObject var viewModel: WatchlistViewModel
    @EnvironmentObject private var appState: AppState

    @State private var showStatusFilter = false

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .center, spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("My Watchlist")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.white)
                            Text("\(viewModel.dramas.count) dramas • @\(username)")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }

                        Spacer()
                        
                        // Sort Menu
                        Menu {
                            ForEach(SortOption.allCases, id: \.self) { option in
                                Button(action: {
                                    viewModel.sortOption = option
                                    viewModel.saveSortPreferences()
                                }) {
                                    Label(
                                        option.displayName,
                                        systemImage: viewModel.sortOption == option ? "checkmark" : option.icon
                                    )
                                }
                            }
                            
                            Divider()
                            
                            Button(action: {
                                viewModel.prioritizeWatching.toggle()
                                viewModel.saveSortPreferences()
                            }) {
                                Label(
                                    "Show Watching First",
                                    systemImage: viewModel.prioritizeWatching ? "checkmark.circle.fill" : "circle"
                                )
                            }
                            .disabled(!viewModel.hasWatchingDramas)
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.up.arrow.down")
                                    .font(.system(size: 14, weight: .semibold))
                                Text("Sort")
                                    .font(.system(size: 14, weight: .medium))
                            }
                            .foregroundColor(.gray)
                            .frame(height: 44)
                            .padding(.horizontal, 12)
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(8)
                        }

                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showStatusFilter.toggle()
                            }
                        }) {
                            Image(systemName: showStatusFilter ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(showStatusFilter ? Color(red: 0.86, green: 0.5, blue: 1.0) : .gray)
                        }
                        .frame(width: 44, height: 44)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(8)

                        Button(action: {
                            Task {
                                await viewModel.fetchWatchlist(username: username, forceRefresh: true)
                            }
                        }) {
                            if viewModel.isLoading {
                                ProgressView()
                                    .tint(Color(red: 0.86, green: 0.5, blue: 1.0))
                            } else {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.gray)
                            }
                        }
                        .frame(width: 44, height: 44)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(8)
                    }

                    // Search bar
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)

                        TextField("Search dramas...", text: $viewModel.searchText)
                            .foregroundColor(.white)
                            .tint(Color(red: 0.86, green: 0.5, blue: 1.0))
                            .textFieldStyle(.plain)
                            .autocorrectionDisabled()

                        if !viewModel.searchText.isEmpty {
                            Button(action: { viewModel.searchText = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(8)

                    if viewModel.serverDown {
                        BannerView(
                            text: "Server appears down. Pull to refresh or try again later.",
                            color: .red
                        )
                    } else if viewModel.isOffline {
                        BannerView(
                            text: "Offline mode: showing last saved watchlist.",
                            color: .orange
                        )
                    }

                    // Status filter
                    if showStatusFilter {
                        StatusFilterView(
                            selectedStatus: $viewModel.selectedStatus,
                            counts: viewModel.statusCounts
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)

                // Content
                ScrollView {
                    VStack(spacing: 12) {
                        if viewModel.isLoading && viewModel.dramas.isEmpty {
                            VStack(spacing: 12) {
                                ProgressView()
                                    .tint(Color(red: 0.86, green: 0.5, blue: 1.0))
                                Text("Loading your watchlist...")
                                    .foregroundColor(.gray)
                                    .font(.caption)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                        } else if viewModel.filteredDramas.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "tv.fill")
                                    .font(.system(size: 32))
                                    .foregroundColor(.gray)
                                Text(viewModel.searchText.isEmpty && viewModel.selectedStatus == .all
                                    ? "Your watchlist is empty"
                                    : "No dramas match your filters"
                                )
                                .foregroundColor(.gray)
                                .font(.caption)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                        } else {
                            // Show "Watching" section header if prioritized
                            if viewModel.prioritizeWatching && viewModel.hasWatchingDramas {
                                let watchingDramas = viewModel.filteredDramas.filter { $0.status == "Watching" }
                                let otherDramas = viewModel.filteredDramas.filter { $0.status != "Watching" }
                                
                                if !watchingDramas.isEmpty {
                                    SectionHeaderView(title: "Watching", count: watchingDramas.count)
                                    
                                    ForEach(watchingDramas) { drama in
                                        DramaRowView(drama: drama) {
                                            onSelectDrama(drama)
                                        }
                                    }
                                }
                                
                                if !otherDramas.isEmpty && !watchingDramas.isEmpty {
                                    SectionHeaderView(title: "Other", count: otherDramas.count)
                                    
                                    ForEach(otherDramas) { drama in
                                        DramaRowView(drama: drama) {
                                            onSelectDrama(drama)
                                        }
                                    }
                                }
                                
                                // If only watching or only others
                                if otherDramas.isEmpty {
                                    // All filtered dramas are watching - already shown above
                                } else if watchingDramas.isEmpty {
                                    ForEach(otherDramas) { drama in
                                        DramaRowView(drama: drama) {
                                            onSelectDrama(drama)
                                        }
                                    }
                                }
                            } else {
                                // No prioritization or no watching dramas
                                ForEach(viewModel.filteredDramas) { drama in
                                    DramaRowView(drama: drama) {
                                        onSelectDrama(drama)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .refreshable {
                    await viewModel.fetchWatchlist(username: username, forceRefresh: true)
                    await appState.autoSyncNotificationsIfNeeded()
                }
                .tint(.white)
                .preferredColorScheme(.dark)

                Spacer(minLength: 80)
            }
        }
        .task(id: username) {
            // Charger uniquement si pas encore chargé durant cette session
            if !viewModel.hasLoadedThisSession {
                await viewModel.fetchWatchlist(username: username)
            }
            _ = await NotificationManager.shared.requestPermissionIfNeeded()
            await appState.autoSyncNotificationsIfNeeded()
        }
    }
}

struct BannerView: View {
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 12))
            Text(text)
                .font(.caption)
                .fontWeight(.medium)
        }
        .foregroundColor(color)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(color.opacity(0.15))
        .cornerRadius(8)
    }
}

struct StatusFilterView: View {
    @Binding var selectedStatus: DramaStatus
    let counts: [String: Int]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(DramaStatus.allCases, id: \.self) { status in
                    let count = status == .all
                        ? counts.values.reduce(0, +)
                        : counts[status.rawValue, default: 0]

                    Button(action: { selectedStatus = status }) {
                        HStack(spacing: 6) {
                            Text(status.displayName)
                                .font(.caption)
                                .fontWeight(.medium)

                            if count > 0 {
                                Text("\(count)")
                                    .font(.caption2)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 2)
                                    .background(Color.white.opacity(0.2))
                                    .cornerRadius(3)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            selectedStatus == status
                                ? Color(red: 0.86, green: 0.5, blue: 1.0)
                                : Color.white.opacity(0.05)
                        )
                        .cornerRadius(6)
                        .foregroundColor(
                            selectedStatus == status ? .white : .gray
                        )
                    }
                }
            }
        }
    }
}

struct SectionHeaderView: View {
    let title: String
    let count: Int
    
    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.gray)
            
            Text("\(count)")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.gray.opacity(0.7))
            
            Spacer()
        }
        .padding(.top, 16)
        .padding(.bottom, 4)
    }
}

#Preview {
    WatchlistView(
        username: "DoctorIceCream",
        onSelectDrama: { _ in },
        viewModel: WatchlistViewModel()
    )
}
