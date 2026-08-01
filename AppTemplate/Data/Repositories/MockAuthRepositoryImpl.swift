import Foundation

/// In-memory implementation used in development builds — accepts one fixed demo
/// credential so the login screen is actually usable with no backend, and rejects
/// everything else the same way a real server would (a 401 `AppError`), so the "wrong
/// password" path is demoable too.
struct MockAuthRepositoryImpl: AuthRepository {
    static let demoEmail = "demo@example.com"
    static let demoPassword = "password"

    func login(email: String, password: String) async throws -> AuthSession {
        guard email == Self.demoEmail, password == Self.demoPassword else {
            throw AppError.network(.requestFailed(statusCode: 401, message: AppStrings.invalidCredentials))
        }
        return AuthSession(token: "mock-token-\(UUID().uuidString)", email: email)
    }

    func logout() async throws {}
}
