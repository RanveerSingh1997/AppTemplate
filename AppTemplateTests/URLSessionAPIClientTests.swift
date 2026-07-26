@testable import AppTemplate
import Foundation
import Testing

/// Thread-safe box for values captured/mutated by a `@Sendable` stub handler and read back
/// from the test body — a plain `var` would race across the handler's and the test's threads.
final class Box<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var value: Value

    init(_ value: Value) { self.value = value }

    func get() -> Value {
        lock.lock(); defer { lock.unlock() }
        return value
    }

    func set(_ newValue: Value) {
        lock.lock(); defer { lock.unlock() }
        value = newValue
    }

    @discardableResult
    func increment() -> Value where Value == Int {
        lock.lock(); defer { lock.unlock() }
        value += 1
        return value
    }
}

/// Intercepts every request instead of hitting the network — lets these tests exercise
/// `URLSessionAPIClient`'s actual retry/auth/error-decoding logic, not just a mock repository
/// that bypasses it entirely.
final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var handler: (@Sendable (URLRequest) -> (Int, Data))?

    override static func canInit(with request: URLRequest) -> Bool { true }
    override static func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.handler, let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        let (statusCode, data) = handler(request)
        let response = HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: nil)
        guard let response else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

@Suite(.serialized)
struct URLSessionAPIClientTests {
    private func makeClient(
        retryPolicy: RetryPolicy = .none,
        interceptors: [APIClientInterceptor] = []
    ) throws -> URLSessionAPIClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        let baseURL = try #require(URL(string: "https://example.com"))
        return URLSessionAPIClient(
            baseURL: baseURL,
            session: URLSession(configuration: configuration),
            interceptors: interceptors,
            retryPolicy: retryPolicy
        )
    }

    @Test
    func authHeaderInterceptorAddsBearerToken() async throws {
        let capturedAuthHeader = Box<String?>(nil)
        StubURLProtocol.handler = { request in
            capturedAuthHeader.set(request.value(forHTTPHeaderField: "Authorization"))
            return (200, Data("{}".utf8))
        }
        let interceptor = AuthHeaderInterceptor { "test-token" }
        let client = try makeClient(interceptors: [interceptor])

        let _: EmptyResponse = try await client.send(APIRequest(path: "items"))

        #expect(capturedAuthHeader.get() == "Bearer test-token")
    }

    @Test
    func authHeaderInterceptorSkipsWhenNoToken() async throws {
        let capturedAuthHeader = Box<String?>(nil)
        StubURLProtocol.handler = { request in
            capturedAuthHeader.set(request.value(forHTTPHeaderField: "Authorization"))
            return (200, Data("{}".utf8))
        }
        let interceptor = AuthHeaderInterceptor { nil }
        let client = try makeClient(interceptors: [interceptor])

        let _: EmptyResponse = try await client.send(APIRequest(path: "items"))

        #expect(capturedAuthHeader.get() == nil)
    }

    @Test
    func decodesServerErrorMessageOnFailure() async throws {
        StubURLProtocol.handler = { _ in
            (422, Data(#"{"message": "Title is required"}"#.utf8))
        }
        let client = try makeClient()

        await #expect(throws: AppError.network(.requestFailed(statusCode: 422, message: "Title is required"))) {
            let _: EmptyResponse = try await client.send(APIRequest(path: "items"))
        }
    }

    @Test
    func fallsBackToGenericMessageWhenBodyUnparseable() async throws {
        StubURLProtocol.handler = { _ in (500, Data("not json".utf8)) }
        let client = try makeClient()

        await #expect(throws: AppError.network(.requestFailed(statusCode: 500, message: nil))) {
            let _: EmptyResponse = try await client.send(APIRequest(path: "items"))
        }
    }

    @Test
    func retriesGetOnServerErrorThenSucceeds() async throws {
        let callCount = Box(0)
        StubURLProtocol.handler = { _ in
            let count = callCount.increment()
            return count < 2 ? (503, Data()) : (200, Data("{}".utf8))
        }
        let client = try makeClient(retryPolicy: RetryPolicy(maxAttempts: 3, retryableMethods: [.get], baseDelay: 0.01))

        let _: EmptyResponse = try await client.send(APIRequest(path: "items"))

        #expect(callCount.get() == 2)
    }

    @Test
    func doesNotRetryPostByDefault() async throws {
        let callCount = Box(0)
        StubURLProtocol.handler = { _ in
            callCount.increment()
            return (503, Data())
        }
        let client = try makeClient(retryPolicy: .default)

        await #expect(throws: AppError.self) {
            let _: EmptyResponse = try await client.send(APIRequest(path: "items", method: .post))
        }
        #expect(callCount.get() == 1)
    }
}
