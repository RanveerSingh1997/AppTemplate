import Foundation

/// Domain-facing contract, same shape as `ItemRepository`/`PriorityRepository`: Presentation
/// depends on this protocol, never the concrete Data-layer implementation. Deliberately
/// doesn't touch `SecureStorageService` itself — same reasoning as `ItemRepository` never
/// touching `SwiftData` directly outside its own `Impl` — storing/clearing the token is the
/// caller's job (`AuthSessionStore`), not this repository's.
protocol AuthRepository {
    func login(email: String, password: String) async throws -> AuthSession
    func logout() async throws
}
