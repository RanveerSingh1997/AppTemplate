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
        case requestFailed(statusCode: Int, message: String?)
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
            return AppStrings.invalidRequestURL
        case .network(.noConnection):
            return AppStrings.noInternetConnection
        case .network(.invalidResponse):
            return AppStrings.serverUnexpectedResponse
        case .network(.requestFailed(let statusCode, let message)):
            return message ?? AppStrings.requestFailed(statusCode: statusCode)
        case .network(.decodingFailed):
            return AppStrings.couldntReadServerResponse
        case .persistence(.saveFailed):
            return AppStrings.couldntSaveYourData
        case .persistence(.fetchFailed):
            return AppStrings.couldntLoadYourData
        case .persistence(.notFound):
            return AppStrings.requestedItemNotFound
        case .validation(.emptyField(let field)):
            return AppStrings.fieldCannotBeEmpty(field)
        case .validation(.tooLong(let field, let max)):
            return AppStrings.fieldTooLong(field, max: max)
        case .configuration(let message), .unknown(let message):
            return message
        }
    }

    /// Coerces any thrown error into an `AppError` — itself unchanged if it already is
    /// one, wrapped as `.unknown(message)` otherwise. For call sites that need to *store*
    /// the error (e.g. `AddEditItemViewModel.saveError: AppError?`), not just display a
    /// string — for display, `error.localizedDescription` already bridges through
    /// `errorDescription` via `LocalizedError`, so no helper is needed there.
    static func from(_ error: Error) -> AppError {
        (error as? AppError) ?? .unknown(error.localizedDescription)
    }
}
