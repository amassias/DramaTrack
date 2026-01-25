import SwiftUI

struct WatchlistView: View {
    let username: String
    let onSelectDrama: (Drama) -> Void

    @StateObject private var viewModel = WatchlistViewModel()
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

                        Button(action: {
                            Task {
                                await viewModel.fetchWatchlist(username: username)
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
                            .textFieldStyle(.plain)

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
                            ForEach(viewModel.filteredDramas) { drama in
                                DramaRowView(drama: drama) {
                                    onSelectDrama(drama)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .refreshable {
                    await viewModel.fetchWatchlist(username: username)
                }

                Spacer(minLength: 80)
            }
        }
        .task {
            if viewModel.dramas.isEmpty {
                await viewModel.fetchWatchlist(username: username)
            }
        }
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

#Preview {
    WatchlistView(username: "DoctorIceCream", onSelectDrama: { _ in })
}
