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
        case episodeNo = "episode_no"
        case ep = "ep"
        case broadcastDate = "broadcast_date"
        case startDate = "start_date"
        case endDate = "end_date"
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
        
        // Parse episode number from various field names (handles both Int and String)
        var episodeNumber: Int? = nil
        
        // Try Int first (using try? to avoid TypeMismatch errors if the field exists but is a String)
        if let num = try? container.decodeIfPresent(Int.self, forKey: .number) {
            episodeNumber = num
        } else if let num = try? container.decodeIfPresent(Int.self, forKey: .episodeNumber) {
            episodeNumber = num
        } else if let num = try? container.decodeIfPresent(Int.self, forKey: .episodeNum) {
            episodeNumber = num
        } else if let num = try? container.decodeIfPresent(Int.self, forKey: .episodeNo) {
            episodeNumber = num
        } else if let num = try? container.decodeIfPresent(Int.self, forKey: .ep) {
            episodeNumber = num
        }
        
        // Try String and convert to Int if no Int found
        if episodeNumber == nil {
            if let numStr = try container.decodeIfPresent(String.self, forKey: .number), let num = Int(numStr) {
                episodeNumber = num
            } else if let numStr = try container.decodeIfPresent(String.self, forKey: .episodeNumber), let num = Int(numStr) {
                episodeNumber = num
            } else if let numStr = try container.decodeIfPresent(String.self, forKey: .episodeNum), let num = Int(numStr) {
                episodeNumber = num
            } else if let numStr = try container.decodeIfPresent(String.self, forKey: .episodeNo), let num = Int(numStr) {
                episodeNumber = num
            } else if let numStr = try container.decodeIfPresent(String.self, forKey: .ep), let num = Int(numStr) {
                episodeNumber = num
            }
        }
        
        guard let num = episodeNumber else {
            throw DecodingError.keyNotFound(
                CodingKeys.number,
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "No episode number found in any expected field")
            )
        }
        number = num
        
        title = try container.decodeIfPresent(String.self, forKey: .title)
        
        // Parse air date from various field names (in priority order)
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
        } else if let dateStr = try container.decodeIfPresent(String.self, forKey: .broadcastDate) {
            parsedDate = Episode.parseDate(dateStr)
        } else if let dateStr = try container.decodeIfPresent(String.self, forKey: .startDate) {
            parsedDate = Episode.parseDate(dateStr)
        } else if let dateStr = try container.decodeIfPresent(String.self, forKey: .endDate) {
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
        if trimmed == "tba" || trimmed == "n/a" || trimmed.contains("unknown") || trimmed == "" {
            return nil
        }

        // Try ISO8601 format
        let iso8601Formatter = ISO8601DateFormatter()
        if let date = iso8601Formatter.date(from: dateStr) {
            return date
        }

        // Try common date formats
        let dateFormatters = [
            "MMM dd, yyyy",
            "MMM d, yyyy",
            "yyyy-MM-dd",
            "dd MMM yyyy",
            "yyyy/MM/dd",
            "MM/dd/yyyy",
            "dd/MM/yyyy",
            "MMMM d, yyyy",
            "d MMMM yyyy"
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
