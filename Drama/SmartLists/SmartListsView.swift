import SwiftUI

struct SmartListsView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = SmartListsViewModel()
    @State private var selectedList: SmartListType?

    var body: some View {
        VStack(spacing: 0) {
            header

            if viewModel.isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                        .tint(Color(red: 0.86, green: 0.5, blue: 1.0))
                    Text("Building your smart lists...")
                        .foregroundColor(.gray)
                        .font(.caption)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(viewModel.lists) { list in
                            SmartListCard(summary: list)
                                .onTapGesture {
                                    selectedList = list.type
                                }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }

            Spacer(minLength: 80)
        }
        .sheet(item: $selectedList) { listType in
            SmartListDetailView(
                type: listType,
                dramas: viewModel.dramas(for: listType)
            )
        }
        .task(id: appState.watchlistViewModel.dramas.count) {
            await viewModel.load(dramas: appState.watchlistViewModel.dramas)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 20))
                            .foregroundColor(Color(red: 0.86, green: 0.5, blue: 1.0))
                        Text("Smart Lists")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                    }
                    Text("Auto-curated lists from your watchlist")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                Spacer()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
    }
}

struct SmartListCard: View {
    let summary: SmartListSummary

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: summary.type.icon)
                .font(.system(size: 20))
                .foregroundColor(Color(red: 0.86, green: 0.5, blue: 1.0))
                .frame(width: 36, height: 36)
                .background(Color.white.opacity(0.08))
                .cornerRadius(8)

            VStack(alignment: .leading, spacing: 4) {
                Text(summary.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                Text(summary.subtitle)
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            Spacer()

            Text("\(summary.count)")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.1))
                .cornerRadius(8)
        }
        .padding(12)
        .background(Color.white.opacity(0.05))
        .cornerRadius(8)
    }
}

struct SmartListDetailView: View {
    let type: SmartListType
    let dramas: [Drama]

    @Environment(\.dismiss) private var dismiss

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

            VStack(spacing: 0) {
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(8)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(type.title)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                        Text(type.subtitle)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }

                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)

                ScrollView {
                    VStack(spacing: 12) {
                        if dramas.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "tray")
                                    .font(.system(size: 32))
                                    .foregroundColor(.gray)
                                Text("No dramas in this list")
                                    .foregroundColor(.gray)
                                    .font(.caption)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                        } else {
                            ForEach(dramas) { drama in
                                DramaRowView(drama: drama) {}
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
        }
    }
}

#Preview {
    SmartListsView()
        .environmentObject(AppState())
}
