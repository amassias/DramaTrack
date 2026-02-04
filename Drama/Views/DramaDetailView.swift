import SwiftUI

struct DramaDetailView: View {
    let drama: Drama
    let onBack: () -> Void

    @StateObject private var viewModel: DramaDetailViewModel

    init(drama: Drama, onBack: @escaping () -> Void) {
        self.drama = drama
        self.onBack = onBack
        _viewModel = StateObject(wrappedValue: DramaDetailViewModel(drama: drama))
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: 16) {
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

                    // Drama header - improved layout
                    HStack(alignment: .top, spacing: 16) {
                        if let imageUrl = drama.image, let url = URL(string: imageUrl) {
                            CachedAsyncImage(url: url) { phase in
                                switch phase {
                                case .success(let image):
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 110, height: 165)
                                        .clipped()
                                case .empty:
                                    ProgressView()
                                        .frame(width: 110, height: 165)
                                case .failure:
                                    Image(systemName: "tv.fill")
                                        .font(.system(size: 32))
                                        .foregroundColor(.gray)
                                        .frame(width: 110, height: 165)
                                @unknown default:
                                    EmptyView()
                                }
                            }
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(12)
                            .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                        } else {
                            Image(systemName: "tv.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.gray)
                                .frame(width: 110, height: 165)
                                .background(Color.white.opacity(0.05))
                                .cornerRadius(12)
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            Text(drama.title)
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                                .lineLimit(3)

                            HStack(spacing: 8) {
                                Text(drama.status)
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(statusColor.opacity(0.3))
                                    .foregroundColor(statusColor)
                                    .cornerRadius(6)

                                if let overallRating = drama.overallRating, !overallRating.isEmpty {
                                    HStack(spacing: 3) {
                                        Image(systemName: "star.fill")
                                            .font(.system(size: 11))
                                            .foregroundColor(.yellow)
                                        Text(overallRating)
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.yellow)
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 5)
                                    .background(Color.yellow.opacity(0.15))
                                    .cornerRadius(6)
                                }
                            }

                            Spacer()

                            if let url = drama.url, let dramURL = URL(string: url) {
                                Link(destination: dramURL) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "link.circle.fill")
                                            .font(.system(size: 14))
                                        Text("View on MDL")
                                            .font(.system(size: 14, weight: .medium))
                                    }
                                    .foregroundColor(Color(red: 0.86, green: 0.5, blue: 1.0))
                                }
                            }
                        }
                        .frame(maxHeight: .infinity, alignment: .topLeading)
                    }
                    .frame(height: 165)
                }
                .padding(16)
                .background(Color.white.opacity(0.02))

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
