import Foundation

struct Episode: Codable, Identifiable {
    let id: UUID
    let number: Int
    let title: String?
    let airDate: Date?

    enum CodingKeys: String, CodingKey {
        case number
        case title
        case airDate = "air_date"
        case airDateAlt = "airDate"
        case releaseDate = "release_date"
        case aired
        case date
        case episodeNumber = "episode_number"
        case episodeNum = "episode"
    }

    init(id: UUID = UUID(), number: Int, title: String? = nil, airDate: Date? = nil) {
        self.id = id
        self.number = number
        self.title = title
        self.airDate = airDate
    }

    init(from decoder: Decoder) throws {
        id = UUID()
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Parse episode number from various field names
        if let num = try container.decodeIfPresent(Int.self, forKey: .number) {
            number = num
        } else if let num = try container.decodeIfPresent(Int.self, forKey: .episodeNumber) {
            number = num
        } else if let num = try container.decodeIfPresent(Int.self, forKey: .episodeNum) {
            number = num
        } else {
            throw DecodingError.keyNotFound(
                CodingKeys.number,
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "No episode number found")
            )
        }
        
        title = try container.decodeIfPresent(String.self, forKey: .title)
        
        // Parse air date from various field names
        var parsedDate: Date?
        
        if let dateStr = try container.decodeIfPresent(String.self, forKey: .airDate) {
            parsedDate = Episode.parseDate(dateStr)
        } else if let dateStr = try container.decodeIfPresent(String.self, forKey: .airDateAlt) {
            parsedDate = Episode.parseDate(dateStr)
        } else if let dateStr = try container.decodeIfPresent(String.self, forKey: .releaseDate) {
            parsedDate = Episode.parseDate(dateStr)
        } else if let dateStr = try container.decodeIfPresent(String.self, forKey: .aired) {
            parsedDate = Episode.parseDate(dateStr)
        } else if let dateStr = try container.decodeIfPresent(String.self, forKey: .date) {
            parsedDate = Episode.parseDate(dateStr)
        }
        
        airDate = parsedDate
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(number, forKey: .number)
        try container.encodeIfPresent(title, forKey: .title)
        if let date = airDate {
            let formatter = ISO8601DateFormatter()
            try container.encode(formatter.string(from: date), forKey: .airDate)
        }
    }

    private static func parseDate(_ dateStr: String?) -> Date? {
        guard let dateStr = dateStr, !dateStr.isEmpty else { return nil }
        
        let trimmed = dateStr.trimmingCharacters(in: .whitespaces).lowercased()
        if trimmed == "tba" || trimmed == "n/a" || trimmed.contains("unknown") {
            return nil
        }

        // Try ISO8601 format
        let iso8601Formatter = ISO8601DateFormatter()
        if let date = iso8601Formatter.date(from: dateStr) {
            return date
        }

        // Try common date formats
        let dateFormatters = [
            "yyyy-MM-dd",
            "MMM d, yyyy",
            "dd MMM yyyy",
            "yyyy/MM/dd",
            "MM/dd/yyyy"
        ]

        for formatString in dateFormatters {
            let formatter = DateFormatter()
            formatter.dateFormat = formatString
            formatter.locale = Locale(identifier: "en_US_POSIX")
            if let date = formatter.date(from: dateStr) {
                return date
            }
        }

        return nil
    }
}

extension Episode {
    var isAired: Bool {
        guard let airDate = airDate else { return false }
        return airDate <= Date()
    }

    var isUpcoming: Bool {
        guard let airDate = airDate else { return false }
        return airDate > Date()
    }

    var airDateFormatted: String {
        guard let airDate = airDate else { return "TBA" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: airDate)
    }
}
