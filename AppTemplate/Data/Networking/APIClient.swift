import Foundation

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
}

/// Describes one call: verb + path + query + headers + body. One request type covers
/// every verb, so adding POST/PUT/DELETE later is a call-site change, not a protocol change.
struct APIRequest {
    var path: String
    var method: HTTPMethod = .get
    var queryItems: [URLQueryItem] = []
    var headers: [String: String] = [:]
    var body: Data?
    /// False for endpoints that must not carry an auth header — login, token refresh
    /// itself, or public endpoints. Interceptors are skipped entirely when this is false.
    var requiresAuth: Bool = true
}

extension APIRequest {
    /// JSON-encodes `json` as the body and sets `Content-Type: application/json` unless
    /// you've already supplied one — the common case, so call sites don't hand-encode.
    init<Body: Encodable>(
        path: String,
        method: HTTPMethod = .get,
        queryItems: [URLQueryItem] = [],
        headers: [String: String] = [:],
        json: Body,
        requiresAuth: Bool = true
    ) throws {
        var headers = headers
        if headers["Content-Type"] == nil {
            headers["Content-Type"] = "application/json"
        }
        do {
            body = try JSONEncoder().encode(json)
        } catch {
            throw AppError.unknown("Could not encode request body: \(error.localizedDescription)")
        }
        self.path = path
        self.method = method
        self.queryItems = queryItems
        self.headers = headers
        self.requiresAuth = requiresAuth
    }

    /// Builds verb + path + query together from one `APIEndpoint` case — a call site never
    /// picks `method:` separately (and so can never pass the wrong verb for a route), the
    /// same reason `APIEndpoint.fetchItems(search:)` takes a `String?` instead of a caller
    /// assembling `URLQueryItem(name: "search", value:)` itself.
    init(
        endpoint: APIEndpoint,
        headers: [String: String] = [:],
        body: Data? = nil,
        requiresAuth: Bool = true
    ) {
        self.path = endpoint.path
        self.method = endpoint.method
        self.queryItems = endpoint.queryItems
        self.headers = headers
        self.body = body
        self.requiresAuth = requiresAuth
    }

    init<Body: Encodable>(
        endpoint: APIEndpoint,
        headers: [String: String] = [:],
        json: Body,
        requiresAuth: Bool = true
    ) throws {
        try self.init(
            path: endpoint.path,
            method: endpoint.method,
            queryItems: endpoint.queryItems,
            headers: headers,
            json: json,
            requiresAuth: requiresAuth
        )
    }
}

/// Decode target for responses with no body (e.g. a 204 from DELETE).
struct EmptyResponse: Decodable {}

protocol APIClient {
    func send<T: Decodable>(_ request: APIRequest) async throws -> T

    /// Uploads a single file with progress. A separate method from `send` because upload
    /// is a stream of progress events over time, not one decoded response — forcing it
    /// through `send`'s `async throws -> T` shape would lose the progress reporting.
    func upload(_ request: APIRequest, file: FileUploadDescriptor) -> AsyncStream<UploadEvent>
}

/// Single-method-per-concern JSON/upload client:
/// - `interceptors` covers auth/signing/logging (see `APIClientInterceptor.swift`).
/// - `authTokenRefresher` covers 401-then-retry, once, regardless of verb.
/// - `retryPolicy` covers transient 5xx/timeout retry, for whichever verbs you mark
///   idempotent (GET by default — see `RetryPolicy`).
/// - `pinnedPublicKeyHashes` (via `makeSession`) covers certificate pinning; empty by
///   default, since a template can't ship real pins for a real backend.
struct URLSessionAPIClient: APIClient {
    let baseURL: URL
    let session: URLSession
    let interceptors: [APIClientInterceptor]
    let authTokenRefresher: (@Sendable () async -> Result<Void, AppError>)?
    let retryPolicy: RetryPolicy
    /// Kept alongside `session` (rather than only baked into it) so `upload`'s separate,
    /// delegate-bound `URLSession` can enforce the same pinning `session` does.
    let pinnedPublicKeyHashes: Set<String>

    init(
        baseURL: URL,
        session: URLSession? = nil,
        interceptors: [APIClientInterceptor] = [],
        authTokenRefresher: (@Sendable () async -> Result<Void, AppError>)? = nil,
        retryPolicy: RetryPolicy = .default,
        pinnedPublicKeyHashes: Set<String> = []
    ) {
        self.baseURL = baseURL
        self.session = session ?? URLSessionAPIClient.makeSession(pinnedPublicKeyHashes: pinnedPublicKeyHashes)
        self.interceptors = interceptors
        self.authTokenRefresher = authTokenRefresher
        self.retryPolicy = retryPolicy
        self.pinnedPublicKeyHashes = pinnedPublicKeyHashes
    }

    /// A session with explicit timeouts instead of `URLSession.shared`'s defaults, and
    /// optional certificate pinning when `pinnedPublicKeyHashes` is non-empty.
    static func makeSession(
        requestTimeout: TimeInterval = 30,
        resourceTimeout: TimeInterval = 60,
        pinnedPublicKeyHashes: Set<String> = []
    ) -> URLSession {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = requestTimeout
        configuration.timeoutIntervalForResource = resourceTimeout
        guard !pinnedPublicKeyHashes.isEmpty else {
            return URLSession(configuration: configuration)
        }
        let validator = PinnedCertificateValidator(pinnedPublicKeyHashes: pinnedPublicKeyHashes)
        return URLSession(configuration: configuration, delegate: validator, delegateQueue: nil)
    }

    // MARK: - send

    func send<T: Decodable>(_ request: APIRequest) async throws -> T {
        try await send(request, didRetryAfterRefresh: false)
    }

    private func send<T: Decodable>(_ request: APIRequest, didRetryAfterRefresh: Bool) async throws -> T {
        let urlRequest = await buildURLRequest(for: request)
        let (data, http) = try await performWithRetries(urlRequest, method: request.method)

        if http.statusCode == HTTPStatusCode.unauthorized, !didRetryAfterRefresh, let authTokenRefresher {
            return try await retryAfterRefresh(request, using: authTokenRefresher)
        }
        guard HTTPStatusCode.isSuccess(http.statusCode) else {
            throw mapFailure(statusCode: http.statusCode, data: data)
        }
        return try decode(data)
    }

    private func retryAfterRefresh<T: Decodable>(
        _ request: APIRequest,
        using refresher: @Sendable () async -> Result<Void, AppError>
    ) async throws -> T {
        switch await refresher() {
        case .success:
            return try await send(request, didRetryAfterRefresh: true)
        case .failure(let error):
            throw error
        }
    }

    private func decode<T: Decodable>(_ data: Data) throws -> T {
        if data.isEmpty, let empty = EmptyResponse() as? T {
            return empty
        }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw AppError.network(.decodingFailed)
        }
    }

    /// Decodes the server's error body (see `APIErrorResponse`) into a real message when
    /// possible, falling back to a generic "status N" message when the body isn't parseable.
    private func mapFailure(statusCode: Int, data: Data) -> AppError {
        let message = (try? JSONDecoder().decode(APIErrorResponse.self, from: data))?.message
        return .network(.requestFailed(statusCode: statusCode, message: message))
    }

    // MARK: - Request construction & transport

    private func buildURLRequest(for request: APIRequest) async -> URLRequest {
        var components = URLComponents(
            url: baseURL.appendingPathComponent(request.path),
            resolvingAgainstBaseURL: false
        )
        if !request.queryItems.isEmpty {
            components?.queryItems = request.queryItems
        }
        var urlRequest = URLRequest(url: components?.url ?? baseURL.appendingPathComponent(request.path))
        urlRequest.httpMethod = request.method.rawValue
        urlRequest.httpBody = request.body
        for (field, value) in request.headers {
            urlRequest.setValue(value, forHTTPHeaderField: field)
        }
        guard request.requiresAuth else { return urlRequest }
        for interceptor in interceptors {
            urlRequest = await interceptor.adapt(urlRequest)
        }
        return urlRequest
    }

    /// Retries only on a transient outcome (5xx, or a timeout raised as `AppError`) and
    /// only for verbs `retryPolicy` marks safe to retry — see `RetryPolicy`'s doc for why
    /// non-idempotent verbs are opt-in.
    private func performWithRetries(
        _ urlRequest: URLRequest,
        method: HTTPMethod
    ) async throws -> (Data, HTTPURLResponse) {
        var attempt = 1
        while true {
            do {
                let (data, http) = try await perform(urlRequest)
                let shouldRetry = HTTPStatusCode.isServerError(http.statusCode)
                    && retryPolicy.shouldRetry(method: method, attempt: attempt)
                guard shouldRetry else { return (data, http) }
                try await Task.sleep(for: retryPolicy.delay(forAttempt: attempt))
                attempt += 1
            } catch let error as AppError where isTransient(error)
                && retryPolicy.shouldRetry(method: method, attempt: attempt) {
                try await Task.sleep(for: retryPolicy.delay(forAttempt: attempt))
                attempt += 1
            }
        }
    }

    private func isTransient(_ error: AppError) -> Bool {
        if case .network(.noConnection) = error { return true }
        guard case .network(.requestFailed(let statusCode, _)) = error else { return false }
        return statusCode == HTTPStatusCode.noResponse || HTTPStatusCode.isServerError(statusCode)
    }

    private func perform(_ urlRequest: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let start = Date()
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch let urlError as URLError
            where [.notConnectedToInternet, .networkConnectionLost].contains(urlError.code) {
            notify(nil, nil, urlRequest, start)
            throw AppError.network(.noConnection)
        } catch is URLError {
            notify(nil, nil, urlRequest, start)
            throw AppError.network(
                .requestFailed(statusCode: HTTPStatusCode.noResponse, message: "The request timed out.")
            )
        } catch {
            notify(nil, nil, urlRequest, start)
            throw AppError.network(.invalidResponse)
        }

        notify(response, data, urlRequest, start)

        guard let http = response as? HTTPURLResponse else {
            throw AppError.network(.invalidResponse)
        }
        return (data, http)
    }

    private func notify(_ response: URLResponse?, _ data: Data?, _ request: URLRequest, _ start: Date) {
        let duration = Date().timeIntervalSince(start)
        interceptors.forEach { $0.didReceive(response: response, data: data, for: request, duration: duration) }
    }

    // MARK: - Upload

    func upload(_ request: APIRequest, file: FileUploadDescriptor) -> AsyncStream<UploadEvent> {
        AsyncStream { continuation in
            Task {
                await startUpload(request, file: file, continuation: continuation)
            }
        }
    }

    private func startUpload(
        _ request: APIRequest,
        file: FileUploadDescriptor,
        continuation: AsyncStream<UploadEvent>.Continuation
    ) async {
        let boundary = UUID().uuidString
        var urlRequest = await buildURLRequest(for: request)
        urlRequest.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        let body: Data
        do {
            body = try MultipartFormData.body(file: file, boundary: boundary)
        } catch let error as AppError {
            continuation.yield(.failed(error))
            continuation.finish()
            return
        } catch {
            continuation.yield(.failed(.unknown(error.localizedDescription)))
            continuation.finish()
            return
        }

        let certificateValidator = pinnedPublicKeyHashes.isEmpty
            ? nil
            : PinnedCertificateValidator(pinnedPublicKeyHashes: pinnedPublicKeyHashes)
        let observer = UploadProgressObserver(continuation: continuation, certificateValidator: certificateValidator)
        let uploadSession = URLSession(configuration: session.configuration, delegate: observer, delegateQueue: nil)
        let task = uploadSession.uploadTask(with: urlRequest, from: body)
        continuation.onTermination = { _ in task.cancel() }
        task.resume()
    }
}
