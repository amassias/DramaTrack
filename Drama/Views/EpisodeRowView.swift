import SwiftUI

struct EpisodeRowView: View {
    let episode: Episode

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            // Episode number badge
            VStack {
                Text("\(episode.number)")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
            }
            .frame(width: 44, height: 44)
            .background(episodeStatusColor.opacity(0.3))
            .foregroundColor(episodeStatusColor)
            .cornerRadius(6)

            // Info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("Episode \(episode.number)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)

                    if episode.isAired {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(Color(red: 0.86, green: 0.5, blue: 1.0))
                    }
                }

                if let title = episode.title {
                    Text(title)
                        .font(.caption)
                        .foregroundColor(.gray)
                        .lineLimit(1)
                } else {
                    EmptyView()
                }
            }

            Spacer()

            // Date
            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: episode.isAired ? "checkmark" : "calendar")
                        .font(.system(size: 12))

                    Text(dateLabel)
                        .font(.caption)
                        .fontWeight(.semibold)
                }
                .foregroundColor(episodeStatusColor)

                if !episode.isAired, let airDate = episode.airDate {
                    Text(shortDateString(from: airDate))
                        .font(.caption2)
                        .foregroundColor(.gray)
                } else {
                    EmptyView()
                }
            }
        }
        .padding(10)
        .background(episodeBgColor)
        .cornerRadius(6)
    }

    private func shortDateString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }

    private var dateLabel: String {
        if episode.airDate != nil {
            return episode.isAired ? "Aired" : "Upcoming"
        }
        return "TBA"
    }

    private var episodeStatusColor: Color {
        guard episode.airDate != nil else {
            return .gray
        }

        return episode.isAired
            ? Color(red: 0.86, green: 0.5, blue: 1.0)
            : Color(red: 0.2, green: 0.6, blue: 1.0)
    }

    private var episodeBgColor: Color {
        guard episode.airDate != nil else {
            return Color.white.opacity(0.05)
        }

        return episode.isAired
            ? Color(red: 0.86, green: 0.5, blue: 1.0).opacity(0.1)
            : Color(red: 0.2, green: 0.6, blue: 1.0).opacity(0.05)
    }
}

#Preview {
    EpisodeRowView(episode: Episode(id: UUID(), number: 1, title: "Test Episode", airDate: Date()))
}
