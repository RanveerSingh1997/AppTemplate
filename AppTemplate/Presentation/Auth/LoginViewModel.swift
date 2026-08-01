import Observation

@Observable
@MainActor
final class LoginViewModel {
    var email: String = ""
    var password: String = ""
    private(set) var isLoggingIn = false
    private(set) var loginError: AppError?

    private let authRepository: AuthRepository
    /// Not localized — same reasoning as `SettingsViewModel.environment.rawValue`: a
    /// developer-facing debug aid, not end-user prose. `nil` outside Dev. Computed by
    /// `AppDependencies` (the composition root — the only place allowed to know
    /// `MockAuthRepositoryImpl` exists) and handed in, rather than this ViewModel
    /// referencing that concrete Data-layer type itself.
    let demoCredentialsHint: String?

    init(authRepository: AuthRepository, demoCredentialsHint: String?) {
        self.authRepository = authRepository
        self.demoCredentialsHint = demoCredentialsHint
    }

    var canSubmit: Bool {
        !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !password.isEmpty && !isLoggingIn
    }

    /// Returns the session's token on success, `nil` on failure — check `loginError` for
    /// what to show. Deliberately doesn't call `AuthSessionStore.signIn(token:)` itself:
    /// this ViewModel depends only on the `AuthRepository` protocol, never the concrete
    /// `AuthSessionStore` (same reason `HomeSplitView`, not `HomeViewModel`, holds
    /// `NavigationCoordinator`) — `LoginView` calls `signIn(token:)` with the value this
    /// returns.
    func login() async -> String? {
        loginError = nil
        isLoggingIn = true
        defer { isLoggingIn = false }
        do {
            let session = try await authRepository.login(email: email, password: password)
            return session.token
        } catch {
            loginError = .from(error)
            return nil
        }
    }
}
