import Foundation

enum ErrorMessage {
    static func userFacing(_ error: Error) -> String {
        if let apiError = error as? APIError {
            return apiError.errorDescription ?? "An error occurred."
        }

        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet:
                return "No internet connection. Please check your network."
            case .timedOut:
                return "The request timed out. Please try again."
            case .cannotFindHost, .cannotConnectToHost:
                return "Unable to reach the server. Please try again later."
            default:
                return "Network error. Please try again."
            }
        }

        return "Something went wrong. Please try again."
    }
}
