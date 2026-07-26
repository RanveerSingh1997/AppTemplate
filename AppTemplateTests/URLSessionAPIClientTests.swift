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

/// Captures every log call instead of printing, so tests can assert on severity —
/// `ConsoleEventLogger` itself has nothing to assert against.
final class RecordingEventLogger: EventLogger, @unchecked Sendable {
    private let lock = NSLock()
    private(set) var entries: [(level: String, message: String)] = []

    func debug(_ message: String, category: LogCategory) { record("debug", message) }
    func info(_ message: String, category: LogCategory) { record("info", message) }
    func warn(_ message: String, category: LogCategory) { record("warn", message) }
    func error(_ message: String, category: LogCategory) { record("error", message) }

    private func record(_ level: String, _ message: String) {
        lock.lock(); defer { lock.unlock() }
        entries.append((level, message))
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
            capturedAuthHeader.set(request.value(forHTTPHeaderField: HeaderField.authorization))
            return (200, Data("{}".utf8))
        }
        let interceptor = AuthHeaderInterceptor { "test-token" }
        let client = try makeClient(interceptors: [interceptor])

        let _: EmptyResponse = try await client.send(APIRequest(endpoint: .fetchItems(search: nil)))

        #expect(capturedAuthHeader.get() == "Bearer test-token")
    }

    @Test
    func authHeaderInterceptorSkipsWhenNoToken() async throws {
        let capturedAuthHeader = Box<String?>(nil)
        StubURLProtocol.handler = { request in
            capturedAuthHeader.set(request.value(forHTTPHeaderField: HeaderField.authorization))
            return (200, Data("{}".utf8))
        }
        let interceptor = AuthHeaderInterceptor { nil }
        let client = try makeClient(interceptors: [interceptor])

        let _: EmptyResponse = try await client.send(APIRequest(endpoint: .fetchItems(search: nil)))

        #expect(capturedAuthHeader.get() == nil)
    }

    @Test
    func decodesServerErrorMessageOnFailure() async throws {
        StubURLProtocol.handler = { _ in
            (422, Data(#"{"message": "Title is required"}"#.utf8))
        }
        let client = try makeClient()

        await #expect(throws: AppError.network(.requestFailed(statusCode: 422, message: "Title is required"))) {
            let _: EmptyResponse = try await client.send(APIRequest(endpoint: .fetchItems(search: nil)))
        }
    }

    @Test
    func fallsBackToGenericMessageWhenBodyUnparseable() async throws {
        StubURLProtocol.handler = { _ in (500, Data("not json".utf8)) }
        let client = try makeClient()

        await #expect(throws: AppError.network(.requestFailed(statusCode: 500, message: nil))) {
            let _: EmptyResponse = try await client.send(APIRequest(endpoint: .fetchItems(search: nil)))
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

        let _: EmptyResponse = try await client.send(APIRequest(endpoint: .fetchItems(search: nil)))

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
            let _: EmptyResponse = try await client.send(APIRequest(endpoint: .createItem))
        }
        #expect(callCount.get() == 1)
    }

    @Test
    func endpointSearchBecomesAQueryItemOnTheOutgoingURL() async throws {
        let capturedQuery = Box<String?>(nil)
        StubURLProtocol.handler = { request in
            capturedQuery.set(request.url?.query)
            return (200, Data("{}".utf8))
        }
        let client = try makeClient()

        let _: EmptyResponse = try await client.send(APIRequest(endpoint: .fetchItems(search: "foo bar")))

        #expect(capturedQuery.get() == "search=foo%20bar")
    }

    @Test
    func noSearchTermMeansNoQueryString() async throws {
        let capturedQuery = Box<String?>(nil)
        StubURLProtocol.handler = { request in
            capturedQuery.set(request.url?.query)
            return (200, Data("{}".utf8))
        }
        let client = try makeClient()

        let _: EmptyResponse = try await client.send(APIRequest(endpoint: .fetchItems(search: nil)))

        #expect(capturedQuery.get() == nil)
    }

    @Test
    func endpointCarriesItsOwnHTTPMethod() async throws {
        let capturedMethod = Box<String?>(nil)
        StubURLProtocol.handler = { request in
            capturedMethod.set(request.httpMethod)
            return (200, Data("{}".utf8))
        }
        let client = try makeClient()

        let _: EmptyResponse = try await client.send(APIRequest(endpoint: .deleteItem(id: "1")))

        #expect(capturedMethod.get() == "DELETE")
    }

    @Test
    func correlationIDInterceptorAddsHeaderWhenMissing() async throws {
        let capturedID = Box<String?>(nil)
        StubURLProtocol.handler = { request in
            capturedID.set(request.value(forHTTPHeaderField: HeaderField.correlationID))
            return (200, Data("{}".utf8))
        }
        let client = try makeClient(interceptors: [CorrelationIDInterceptor()])

        let _: EmptyResponse = try await client.send(APIRequest(endpoint: .fetchItems(search: nil)))

        #expect(capturedID.get() != nil)
    }

    @Test
    func loggingInterceptorDowngrades404OnExpectedRouteToInfo() async throws {
        StubURLProtocol.handler = { _ in (404, Data()) }
        let recorder = RecordingEventLogger()
        let client = try makeClient(interceptors: [LoggingInterceptor(logger: recorder)])

        do {
            let _: EmptyResponse = try await client.send(APIRequest(endpoint: .deleteItem(id: "already-gone")))
        } catch {
            // Expected: a 404 always throws. This test only cares what got logged.
        }

        #expect(recorder.entries.contains { $0.level == "info" })
        #expect(!recorder.entries.contains { $0.level == "warn" })
    }

    @Test
    func loggingInterceptorTreats404OnUnclassifiedRouteAsWarning() async throws {
        StubURLProtocol.handler = { _ in (404, Data()) }
        let recorder = RecordingEventLogger()
        let client = try makeClient(interceptors: [LoggingInterceptor(logger: recorder)])

        do {
            let _: EmptyResponse = try await client.send(APIRequest(path: "other"))
        } catch {
            // Expected: a 404 always throws. This test only cares what got logged.
        }

        #expect(recorder.entries.contains { $0.level == "warn" })
    }
}
