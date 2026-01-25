import SwiftUI

struct DramaDetailView: View {
    let drama: Drama
    let onBack: () -> Void

    @StateObject private var viewModel: DramaDetailViewModel
    @State private var localNotificationEnabled = false

    init(drama: Drama, onBack: @escaping () -> Void) {
        self.drama = drama
        self.onBack = onBack
        _viewModel = StateObject(wrappedValue: DramaDetailViewModel(drama: drama))
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: 12) {
                    // Back button
                    Button(action: onBack) {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.gray)
                    }
                    .frame(height: 44)

                    // Drama header
                    HStack(alignment: .top, spacing: 12) {
                        if let imageUrl = drama.image, let url = URL(string: imageUrl) {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .success(let image):
                                    image
                                        .resizable()
                                        .scaledToFill()
                                case .loading:
                                    ProgressView()
                                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                                case .empty, .failure:
                                    Image(systemName: "tv.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(.gray)
                                @unknown default:
                                    EmptyView()
                                }
                            }
                            .frame(width: 80, height: 120)
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(8)
                        } else {
                            Image(systemName: "tv.fill")
                                .font(.system(size: 32))
                                .foregroundColor(.gray)
                                .frame(width: 80, height: 120)
                                .background(Color.white.opacity(0.05))
                                .cornerRadius(8)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text(drama.title)
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                                .lineLimit(2)

                            HStack(spacing: 8) {
                                Text(drama.status)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(statusColor.opacity(0.3))
                                    .foregroundColor(statusColor)
                                    .cornerRadius(4)

                                if let rating = drama.rating, !rating.isEmpty {
                                    Text("★ \(rating)")
                                        .font(.caption)
                                        .foregroundColor(.yellow)
                                }
                            }

                            Spacer()

                            if let url = drama.url, let dramURL = URL(string: url) {
                                Link(destination: dramURL) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "link")
                                        Text("View on MDL")
                                    }
                                    .font(.caption)
                                    .foregroundColor(Color(red: 0.86, green: 0.5, blue: 1.0))
                                }
                            }
                        }
                        .frame(maxHeight: .infinity, alignment: .topLeading)
                    }
                }
                .padding(16)

                // Notification toggle
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        Image(systemName: localNotificationEnabled ? "bell.fill" : "bell.slash.fill")
                            .font(.system(size: 16))
                            .foregroundColor(localNotificationEnabled ? Color(red: 0.86, green: 0.5, blue: 1.0) : .gray)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Episode Notifications")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                            Text("Get notified on air dates")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }

                        Spacer()

                        Toggle("", isOn: $localNotificationEnabled)
                            .onChange(of: localNotificationEnabled) { _ in
                                Task {
                                    await viewModel.toggleNotification()
                                }
                            }
                    }
                    .padding(12)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(8)
                }
                .padding(.horizontal, 16)

                // Episodes
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Episodes (\(viewModel.episodes.count))")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)

                        if viewModel.upcomingCount > 0 {
                            Text("\(viewModel.upcomingCount) upcoming")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color(red: 0.2, green: 0.8, blue: 0.4).opacity(0.3))
                                .foregroundColor(Color(red: 0.2, green: 0.8, blue: 0.4))
                                .cornerRadius(4)
                        }

                        Spacer()
                    }
                    .padding(.horizontal, 16)

                    if viewModel.isLoading {
                        HStack {
                            Spacer()
                            ProgressView()
                                .tint(Color(red: 0.86, green: 0.5, blue: 1.0))
                            Spacer()
                        }
                        .frame(height: 200)
                    } else if let error = viewModel.error {
                        VStack(spacing: 12) {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                                .multilineTextAlignment(.center)

                            Button(action: {
                                Task {
                                    await viewModel.loadEpisodes()
                                }
                            }) {
                                Text("Try Again")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                        .padding(.horizontal, 16)
                    } else if viewModel.episodes.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "tv.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.gray)
                            Text("No episode information available")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    } else {
                        ScrollView {
                            VStack(spacing: 8) {
                                ForEach(viewModel.episodes) { episode in
                                    EpisodeRowView(episode: episode)
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                }
                .frame(maxHeight: .infinity, alignment: .topLeading)

                Spacer(minLength: 80)
            }
        }
        .task {
            await viewModel.loadEpisodes()
        }
        .onChange(of: viewModel.notificationEnabled) { newValue in
            localNotificationEnabled = newValue
        }
        .onAppear {
            localNotificationEnabled = viewModel.notificationEnabled
        }
    }

    private var statusColor: Color {
        switch drama.status {
        case "Watching":
            return Color(red: 0.2, green: 0.8, blue: 0.4)
        case "Completed":
            return Color(red: 0.86, green: 0.5, blue: 1.0)
        case "Plan to Watch":
            return Color(red: 0.2, green: 0.6, blue: 1.0)
        case "On-Hold":
            return Color(red: 1.0, green: 0.7, blue: 0.2)
        case "Dropped":
            return Color(red: 1.0, green: 0.3, blue: 0.3)
        default:
            return .gray
        }
    }
}

#Preview {
    DramaDetailView(
        drama: Drama(
            title: "Test Drama",
            slug: "123-test",
            status: "Watching",
            rating: "8.5",
            image: nil,
            url: nil
        ),
        onBack: { }
    )
}
