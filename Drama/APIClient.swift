import Foundation

enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case decodingError(String)
    case networkError(String)
    case userNotFound
    case serverError
    case timeout
    case unknown

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid server response"
        case .decodingError(let msg):
            return "Failed to decode: \(msg)"
        case .networkError(let msg):
            return msg
        case .userNotFound:
            return "User not found. Please check your username."
        case .serverError:
            return "Server error. Please try again later."
        case .timeout:
            return "Request timed out. Please check your connection."
        case .unknown:
            return "Unknown error occurred"
        }
    }
}

class APIClient {
    static let shared = APIClient()

    private let baseURL = "https://mydramalist-psi.vercel.app"
    private let timeoutInterval: TimeInterval = 20.0
    private let maxRetries = 3
    private let backoffDelays: [TimeInterval] = [0.5, 1.5, 3.0]

    private let session: URLSession

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 20.0
        config.timeoutIntervalForResource = 30.0
        config.waitsForConnectivity = true
        self.session = URLSession(configuration: config)
    }

    // MARK: - Public Methods

    func fetchWatchlist(username: String) async throws -> DramaListResponse {
        let endpoint = "/api/dramalist/\(username)"
        let url = try buildURL(endpoint: endpoint)

        let data = try await fetchWithRetry(url: url)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            let response = try decoder.decode(DramaListResponse.self, from: data)
            return response
        } catch {
            throw APIError.decodingError(error.localizedDescription)
        }
    }

    func fetchEpisodes(slug: String) async throws -> [Episode] {
        let endpoint = "/api/id/\(slug)/episodes"
        let url = try buildURL(endpoint: endpoint)

        let data = try await fetchWithRetry(url: url)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            // Try array format first
            if let episodes = try? decoder.decode([Episode].self, from: data) {
                return episodes
            }

            // Try object with episodes key
            if let response = try? decoder.decode([String: [Episode]].self, from: data),
               let episodes = response["episodes"] ?? response["episode_list"] {
                return episodes
            }

            return []
        } catch {
            throw APIError.decodingError(error.localizedDescription)
        }
    }

    // MARK: - Private Methods

    private func buildURL(endpoint: String) throws -> URL {
        let urlString = baseURL + endpoint
        guard let url = URL(string: urlString) else {
            throw APIError.invalidURL
        }
        return url
    }

    private func fetchWithRetry(url: URL) async throws -> Data {
        var lastError: Error?

        for attempt in 0..<maxRetries {
            do {
                let (data, response) = try await session.data(from: url)

                guard let httpResponse = response as? HTTPURLResponse else {
                    throw APIError.invalidResponse
                }

                switch httpResponse.statusCode {
                case 200...299:
                    return data
                case 404:
                    throw APIError.userNotFound
                case 500...599:
                    throw APIError.serverError
                default:
                    throw APIError.networkError("HTTP \(httpResponse.statusCode)")
                }
            } catch let error as APIError {
                lastError = error
                // Don't retry on 404 or invalid URL
                if case .userNotFound = error {
                    throw error
                }
                if case .invalidURL = error {
                    throw error
                }
            } catch {
                lastError = error
            }

            // Wait before retry (except on last attempt)
            if attempt < maxRetries - 1 {
                let delay = backoffDelays[attempt]
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }

        if let error = lastError {
            if error is CancellationError {
                throw APIError.timeout
            }
            throw error
        }

        throw APIError.unknown
    }
}
