import Foundation

/// Single error vocabulary for the whole app. Every layer (network, persistence,
/// validation, configuration) throws this instead of its own ad hoc error type, so
/// callers — ViewModels in particular — switch on one type instead of having to know
/// what each dependency happens to throw.
enum AppError: Error, LocalizedError, Equatable {
    case network(NetworkFailure)
    case persistence(PersistenceFailure)
    case validation(ValidationFailure)
    case configuration(String)
    case unknown(String)

    enum NetworkFailure: Equatable {
        case invalidURL
        case noConnection
        case invalidResponse
        case requestFailed(statusCode: Int)
        case decodingFailed
    }

    enum PersistenceFailure: Equatable {
        case saveFailed
        case fetchFailed
        case notFound
    }

    enum ValidationFailure: Equatable {
        case emptyField(String)
        case tooLong(field: String, max: Int)
    }

    var errorDescription: String? {
        switch self {
        case .network(.invalidURL):
            return "The request URL is invalid."
        case .network(.noConnection):
            return "No internet connection."
        case .network(.invalidResponse):
            return "The server returned an unexpected response."
        case .network(.requestFailed(let statusCode)):
            return "The request failed (status \(statusCode))."
        case .network(.decodingFailed):
            return "Couldn't read the server's response."
        case .persistence(.saveFailed):
            return "Couldn't save your data."
        case .persistence(.fetchFailed):
            return "Couldn't load your data."
        case .persistence(.notFound):
            return "The requested item couldn't be found."
        case .validation(.emptyField(let field)):
            return "\(field) can't be empty."
        case .validation(.tooLong(let field, let max)):
            return "\(field) can't be longer than \(max) characters."
        case .configuration(let message), .unknown(let message):
            return message
        }
    }
}
