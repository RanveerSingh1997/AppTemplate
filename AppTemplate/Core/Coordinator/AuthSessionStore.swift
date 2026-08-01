import Observation

/// Whether the app is signed in — the concrete `@Observable` state `AppContainerView` binds
/// to directly to decide "show `LoginView` or `MainTabView`," the same reason it binds to
/// `NavigationCoordinator`/`AlertCenter` directly rather than through a protocol: this is
/// live presentation state a root view owns, not a swappable Data-layer implementation.
/// Deliberately doesn't touch the network — `AuthRepository.login`/`logout` handle that;
/// this only tracks/persists whether a token exists, via `SecureStorageService`.
@Observable
@MainActor
final class AuthSessionStore {
    private(set) var isAuthenticated: Bool
    private let secureStorageService: SecureStorageService

    init(secureStorageService: SecureStorageService) {
        self.secureStorageService = secureStorageService
        if case .success(.some) = secureStorageService.get(forKey: SecureStorageKey.authToken) {
            isAuthenticated = true
        } else {
            isAuthenticated = false
        }
    }

    func signIn(token: String) {
        _ = secureStorageService.set(token, forKey: SecureStorageKey.authToken)
        isAuthenticated = true
    }

    func signOut() {
        _ = secureStorageService.delete(forKey: SecureStorageKey.authToken)
        isAuthenticated = false
    }
}
