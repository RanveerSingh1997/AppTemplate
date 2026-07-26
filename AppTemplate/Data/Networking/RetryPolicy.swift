import Foundation

/// Controls automatic retry for transient failures (5xx responses, timeouts) — separate
/// from the one-time 401-refresh-retry in `URLSessionAPIClient`, which always applies
/// regardless of verb since it isn't a transient-failure concern.
///
/// Defaults to retrying only `.get` — retrying `.post`/`.put`/`.delete` automatically risks
/// double-submitting a non-idempotent request if the first attempt actually succeeded but
/// the response was lost. Opt other verbs in only for endpoints you know are idempotent.
struct RetryPolicy: Sendable {
    var maxAttempts: Int
    var retryableMethods: Set<HTTPMethod>
    var baseDelay: TimeInterval

    static let `default` = RetryPolicy(maxAttempts: 2, retryableMethods: [.get], baseDelay: 0.5)
    static let none = RetryPolicy(maxAttempts: 1, retryableMethods: [], baseDelay: 0)

    func shouldRetry(method: HTTPMethod, attempt: Int) -> Bool {
        retryableMethods.contains(method) && attempt < maxAttempts
    }

    func delay(forAttempt attempt: Int) -> Duration {
        .seconds(baseDelay * Double(attempt))
    }
}
