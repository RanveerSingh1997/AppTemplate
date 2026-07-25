import Foundation

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
}

/// Describes one call: verb + path + optional headers/body. One request type covers
/// every verb, so adding POST/PUT/DELETE later is a call-site change, not a protocol change.
struct APIRequest {
    var path: String
    var method: HTTPMethod = .get
    var headers: [String: String] = [:]
    var body: Data?
    /// False for endpoints that must not carry an auth header — login, token refresh
    /// itself, or public endpoints. Interceptors in `URLSessionAPIClient.interceptors`
    /// are skipped entirely when this is false.
    var requiresAuth: Bool = true
}

/// Decode target for responses with no body (e.g. a 204 from DELETE).
struct EmptyResponse: Decodable {}

/// Adapts an outgoing request before it's sent — the seam for auth headers, request
/// signing, or correlation IDs, without growing `APIClient`'s method count or `send`'s body.
/// Interceptors run in array order; each sees the previous one's changes.
protocol APIClientInterceptor: Sendable {
    func adapt(_ request: URLRequest) async -> URLRequest
    /// Fires after every response, success or failure — e.g. for logging. Most
    /// interceptors don't need this; the default does nothing.
    func didReceive(response: URLResponse?, data: Data?)
}

extension APIClientInterceptor {
    func didReceive(response: URLResponse?, data: Data?) {}
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

protocol APIClient {
    func send<T: Decodable>(_ request: APIRequest) async throws -> T
}

/// Single-method JSON client. `interceptors` covers auth/signing/logging; `authTokenRefresher`
/// covers 401-then-retry. Both are optional and empty/nil by default — wire them in once you
/// have an auth flow (see `AppDependencies`), rather than growing `send`'s cases by hand.
struct URLSessionAPIClient: APIClient {
    let baseURL: URL
    let session: URLSession
    let interceptors: [APIClientInterceptor]
    /// Called once on a 401. Return `.success` to retry the original request with
    /// whatever the interceptors now read (e.g. a freshly-refreshed token); `.failure`
    /// propagates as the request's error without retrying.
    let authTokenRefresher: (@Sendable () async -> Result<Void, AppError>)?

    init(
        baseURL: URL,
        session: URLSession = URLSessionAPIClient.makeSession(),
        interceptors: [APIClientInterceptor] = [],
        authTokenRefresher: (@Sendable () async -> Result<Void, AppError>)? = nil
    ) {
        self.baseURL = baseURL
        self.session = session
        self.interceptors = interceptors
        self.authTokenRefresher = authTokenRefresher
    }

    /// A session with explicit, sane timeouts instead of `URLSession.shared`'s defaults —
    /// tune `requestTimeout`/`resourceTimeout` per app if 30s/60s doesn't fit your API.
    static func makeSession(requestTimeout: TimeInterval = 30, resourceTimeout: TimeInterval = 60) -> URLSession {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = requestTimeout
        configuration.timeoutIntervalForResource = resourceTimeout
        return URLSession(configuration: configuration)
    }

    func send<T: Decodable>(_ request: APIRequest) async throws -> T {
        try await send(request, didRetryAfterRefresh: false)
    }

    private func send<T: Decodable>(_ request: APIRequest, didRetryAfterRefresh: Bool) async throws -> T {
        var urlRequest = URLRequest(url: baseURL.appendingPathComponent(request.path))
        urlRequest.httpMethod = request.method.rawValue
        urlRequest.httpBody = request.body
        for (field, value) in request.headers {
            urlRequest.setValue(value, forHTTPHeaderField: field)
        }
        if request.requiresAuth {
            for interceptor in interceptors {
                urlRequest = await interceptor.adapt(urlRequest)
            }
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch let urlError as URLError
            where [.notConnectedToInternet, .networkConnectionLost].contains(urlError.code) {
            throw AppError.network(.noConnection)
        } catch let urlError as URLError where urlError.code == .timedOut {
            throw AppError.network(.requestFailed(statusCode: -1))
        } catch {
            throw AppError.network(.invalidResponse)
        }

        interceptors.forEach { $0.didReceive(response: response, data: data) }

        guard let http = response as? HTTPURLResponse else {
            throw AppError.network(.invalidResponse)
        }

        if http.statusCode == 401, !didRetryAfterRefresh, let authTokenRefresher {
            switch await authTokenRefresher() {
            case .success:
                return try await send(request, didRetryAfterRefresh: true)
            case .failure(let error):
                throw error
            }
        }

        guard (200..<300).contains(http.statusCode) else {
            throw AppError.network(.requestFailed(statusCode: http.statusCode))
        }

        if data.isEmpty, let empty = EmptyResponse() as? T {
            return empty
        }

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw AppError.network(.decodingFailed)
        }
    }
}
