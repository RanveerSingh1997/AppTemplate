import Foundation

/// Secure key-value storage (tokens, credentials). Wired into `URLSessionAPIClient` via
/// `AuthHeaderInterceptor` already (see `AppDependencies`) — an auth feature just needs to
/// call `set(_:forKey: SecureStorageKey.authToken)` after login, nothing in the
/// networking layer changes.
protocol SecureStorageService: Sendable {
    func set(_ value: String, forKey key: String) -> Result<Void, AppError>
    func get(forKey key: String) -> Result<String?, AppError>
    func delete(forKey key: String) -> Result<Void, AppError>
}

/// Well-known keys, shared between whatever sets a value (an auth feature) and whatever
/// reads it (`AuthHeaderInterceptor`) so both sides can't drift onto different string
/// literals for the same value.
enum SecureStorageKey {
    static let authToken = "authToken"
}
