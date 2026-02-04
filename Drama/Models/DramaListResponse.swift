import Foundation

struct DramaListResponse: Codable {
    let username: String
    let userId: String?
    let dramas: [Drama]
    let total: Int
    let url: String?

    enum CodingKeys: String, CodingKey {
        case username
        case userId = "user_id"
        case dramas
        case total
        case url
    }
}

struct Drama: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let slug: String
    let status: String
    let rating: String?
    let image: String?
    let url: String?
    var overallRating: String?

    enum CodingKeys: String, CodingKey {
        case title, slug, status, rating, image, url
    }

    init(title: String, slug: String, status: String, rating: String? = nil, image: String? = nil, url: String? = nil, overallRating: String? = nil) {
        self.id = slug
        self.title = title
        self.slug = slug
        self.status = status
        self.rating = rating
        self.image = image
        self.url = url
        self.overallRating = overallRating
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decode(String.self, forKey: .title)
        slug = try container.decode(String.self, forKey: .slug)
        status = try container.decode(String.self, forKey: .status)
        rating = try container.decodeIfPresent(String.self, forKey: .rating)
        image = try container.decodeIfPresent(String.self, forKey: .image)
        url = try container.decodeIfPresent(String.self, forKey: .url)
        id = slug
        overallRating = nil
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(title, forKey: .title)
        try container.encode(slug, forKey: .slug)
        try container.encode(status, forKey: .status)
        try container.encodeIfPresent(rating, forKey: .rating)
        try container.encodeIfPresent(image, forKey: .image)
        try container.encodeIfPresent(url, forKey: .url)
    }
}

struct DramaDetail: Codable {
    let slug: String
    let title: String
    let rating: String?
    let image: String?
    let synopsis: String?
    let country: String?
    let episodes: String?
    let aired: String?
    
    enum CodingKeys: String, CodingKey {
        case slug, title, rating, image, synopsis, country, episodes, aired
    }
}

enum DramaStatus: String, CaseIterable {
    case all = "All"
    case watching = "Watching"
    case planToWatch = "Plan to Watch"
    case completed = "Completed"
    case onHold = "On-Hold"
    case dropped = "Dropped"

    var displayName: String {
        self.rawValue
    }
}

enum SortOption: String, CaseIterable {
    case titleAZ = "Title (A-Z)"
    case titleZA = "Title (Z-A)"
    case status = "By Status"
    case ratingHighToLow = "Rating (High to Low)"
    case ratingLowToHigh = "Rating (Low to High)"
    
    var displayName: String {
        self.rawValue
    }
    
    var icon: String {
        switch self {
        case .titleAZ: return "textformat.abc"
        case .titleZA: return "textformat.abc"
        case .status: return "list.bullet"
        case .ratingHighToLow: return "star.fill"
        case .ratingLowToHigh: return "star"
        }
    }
}
