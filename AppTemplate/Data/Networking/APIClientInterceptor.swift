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

/// Attaches a fresh ID to every request that doesn't already have one, so a client-side log
/// line and the matching server-side request log can be joined by grepping the same value.
/// Runs first in the chain — every other interceptor, and `LoggingInterceptor` in
/// particular, should see the ID already present.
struct CorrelationIDInterceptor: APIClientInterceptor {
    func adapt(_ request: URLRequest) async -> URLRequest {
        guard request.value(forHTTPHeaderField: HeaderField.correlationID) == nil else { return request }
        var request = request
        request.setValue(UUID().uuidString, forHTTPHeaderField: HeaderField.correlationID)
        return request
    }
}

/// Reads the current token from `tokenProvider` (typically backed by
/// `SecureStorageService`) and sets it as `Authorization: Bearer <token>` on every request
/// that doesn't already have that header and has `requiresAuth == true`. Returning `nil`
/// (no signed-in user) leaves the request unmodified rather than sending a bad header.
struct AuthHeaderInterceptor: APIClientInterceptor {
    let tokenProvider: @Sendable () async -> String?

    func adapt(_ request: URLRequest) async -> URLRequest {
        let hasAuthHeader = request.value(forHTTPHeaderField: HeaderField.authorization) != nil
        guard !hasAuthHeader, let token = await tokenProvider() else {
            return request
        }
        var request = request
        request.setValue("Bearer \(token)", forHTTPHeaderField: HeaderField.authorization)
        return request
    }
}

/// Logs correlation ID, method, path, status, and duration through `EventLogger` — never
/// headers or body, so it's safe to leave on in QA/Prod without a redaction pass. Severity
/// follows the response's status class, except a 404 on a route `APIEndpoint` classifies as
/// expected (e.g. acting on an id that's already gone) logs as info instead of warn — so a
/// normal race doesn't look identical to a real client bug on a dashboard.
struct LoggingInterceptor: APIClientInterceptor {
    let logger: EventLogger

    func adapt(_ request: URLRequest) async -> URLRequest {
        request
    }

    func didReceive(response: URLResponse?, data: Data?, for request: URLRequest, duration: TimeInterval) {
        let correlationID = request.value(forHTTPHeaderField: HeaderField.correlationID) ?? "-"
        let method = request.httpMethod ?? "GET"
        let path = request.url?.path ?? request.url?.absoluteString ?? "?"
        let durationMs = Int(duration * 1000)
        let prefix = "[\(correlationID)] \(method) \(path)"

        guard let http = response as? HTTPURLResponse else {
            logger.error("\(prefix) -> no response (\(durationMs)ms)", category: .network)
            return
        }

        let message = "\(prefix) -> \(http.statusCode) (\(durationMs)ms)"
        log(message, statusCode: http.statusCode, path: path)
    }

    private func log(_ message: String, statusCode: Int, path: String) {
        if HTTPStatusCode.isSuccess(statusCode) {
            logger.info(message, category: .network)
        } else if statusCode == HTTPStatusCode.notFound && APIEndpoint.isExpectedNotFound(forPath: path) {
            logger.info(message, category: .network)
        } else if HTTPStatusCode.isClientError(statusCode) {
            logger.warn(message, category: .network)
        } else {
            logger.error(message, category: .network)
        }
    }
}
