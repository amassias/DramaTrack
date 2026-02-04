import SwiftUI

struct DramaRowView: View {
    let drama: Drama
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 12) {
                // Poster
                if let imageUrl = drama.image, let url = URL(string: imageUrl) {
                    CachedAsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                        case .empty:
                            ProgressView()
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        case .failure:
                            Image(systemName: "tv.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.gray)
                        @unknown default:
                            EmptyView()
                        }
                    }
                    .frame(width: 60, height: 90)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(6)
                } else {
                    Image(systemName: "tv.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.gray)
                        .frame(width: 60, height: 90)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(6)
                }

                // Info
                VStack(alignment: .leading, spacing: 8) {
                    Text(drama.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(2)

                    HStack(spacing: 8) {
                        Text(drama.status)
                            .font(.caption)
                            .fontWeight(.medium)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(statusColor.opacity(0.3))
                            .foregroundColor(statusColor)
                            .cornerRadius(4)

                        if let overallRating = drama.overallRating, !overallRating.isEmpty {
                            HStack(spacing: 2) {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(.yellow)
                                Text(overallRating)
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.yellow)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.yellow.opacity(0.15))
                            .cornerRadius(4)
                        } else {
                            HStack(spacing: 2) {
                                Image(systemName: "star")
                                    .font(.system(size: 10))
                                    .foregroundColor(.gray.opacity(0.5))
                                ProgressView()
                                    .scaleEffect(0.6)
                                    .tint(.gray.opacity(0.5))
                            }
                        }

                        Spacer()
                    }

                    Spacer()
                }
                .frame(maxHeight: .infinity, alignment: .topLeading)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.gray)
            }
            .frame(height: 90)
            .padding(10)
            .background(Color.white.opacity(0.05))
            .cornerRadius(8)
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
    DramaRowView(
        drama: Drama(
            title: "Test Drama",
            slug: "123-test",
            status: "Watching",
            rating: "8.5",
            image: nil,
            url: nil
        ),
        onTap: { }
    )
}
