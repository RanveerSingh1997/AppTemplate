import Foundation

/// What a successful login returns — just enough to authenticate subsequent requests
/// (`token`, stored via `SecureStorageService` and read by `AuthHeaderInterceptor`) and
/// label whose session it is (`email`). Not a full user-profile model — add one separately
/// (`Domain/Models/User.swift`) if a real app needs name/avatar/roles/etc.; keep this
/// scoped to what auth itself needs.
struct AuthSession: Sendable {
    let token: String
    let email: String
}
