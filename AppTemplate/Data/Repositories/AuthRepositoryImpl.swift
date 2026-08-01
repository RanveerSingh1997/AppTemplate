import Foundation

/// `login`/`logout` both pass `requiresAuth: false`/`true` explicitly rather than relying on
/// `APIRequest`'s default — login has no token yet to attach, logout is exactly the request
/// that needs the *current* token attached so the server knows which session to invalidate.
struct AuthRepositoryImpl: AuthRepository {
    let apiClient: APIClient

    func login(email: String, password: String) async throws -> AuthSession {
        let request = try APIRequest(
            endpoint: .login,
            json: LoginRequestDTO(email: email, password: password),
            requiresAuth: false
        )
        let response: AuthResponseDTO = try await apiClient.send(request)
        return response.asDomain
    }

    func logout() async throws {
        let request = APIRequest(endpoint: .logout, requiresAuth: true)
        let _: EmptyResponse = try await apiClient.send(request)
    }
}
