import Foundation

/// Adapts an outgoing request before it's sent — the seam for auth headers, request
/// signing, or correlation IDs, without growing `APIClient`'s method count or `send`'s body.
/// Interceptors run in array order; each sees the previous one's changes.
protocol APIClientInterceptor: Sendable {
    func adapt(_ request: URLRequest) async -> URLRequest
    /// Fires after every response, success or failure — logging's hook. `duration` covers
    /// only the network call itself (not decoding). Most interceptors don't need this;
    /// the default does nothing.
    func didReceive(response: URLResponse?, data: Data?, for request: URLRequest, duration: TimeInterval)
}

extension APIClientInterceptor {
    func didReceive(response: URLResponse?, data: Data?, for request: URLRequest, duration: TimeInterval) {}
}

/// Reads the current token from `tokenProvider` (typically backed by
/// `SecureStorageService`) and sets it as `Authorization: Bearer <token>` on every request
/// that doesn't already have that header and has `requiresAuth == true`. Returning `nil`
/// (no signed-in user) leaves the request unmodified rather than sending a bad header.
struct AuthHeaderInterceptor: APIClientInterceptor {
    let tokenProvider: @Sendable () async -> String?

    func adapt(_ request: URLRequest) async -> URLRequest {
        guard request.value(forHTTPHeaderField: "Authorization") == nil, let token = await tokenProvider() else {
            return request
        }
        var request = request
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return request
    }
}

/// Logs method, path, status, and duration through `EventLogger` — never headers or body,
/// so it's safe to leave on in QA/Prod without a redaction pass. Severity follows the
/// response's status class (2xx info, 4xx warn, 5xx/no-response error).
struct LoggingInterceptor: APIClientInterceptor {
    let logger: EventLogger

    func adapt(_ request: URLRequest) async -> URLRequest {
        request
    }

    func didReceive(response: URLResponse?, data: Data?, for request: URLRequest, duration: TimeInterval) {
        let method = request.httpMethod ?? "GET"
        let path = request.url?.path ?? request.url?.absoluteString ?? "?"
        let durationMs = Int(duration * 1000)

        guard let http = response as? HTTPURLResponse else {
            logger.error("\(method) \(path) -> no response (\(durationMs)ms)", category: .network)
            return
        }

        let message = "\(method) \(path) -> \(http.statusCode) (\(durationMs)ms)"
        if HTTPStatusCode.isSuccess(http.statusCode) {
            logger.info(message, category: .network)
        } else if HTTPStatusCode.isClientError(http.statusCode) {
            logger.warn(message, category: .network)
        } else {
            logger.error(message, category: .network)
        }
    }
}
