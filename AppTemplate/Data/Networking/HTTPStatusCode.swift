import Foundation

/// Every HTTP status code/range the networking layer cares about, defined once — nothing
/// else in `Data/Networking` compares against a bare `401` or `(500..<600)` inline.
enum HTTPStatusCode {
    static let unauthorized = 401
    static let notFound = 404

    /// Sentinel for failures that never got a real HTTP status (timeouts, transport errors)
    /// before they're wrapped in `AppError.network(.requestFailed)`. Not a code a server
    /// would ever send.
    static let noResponse = -1

    static func isSuccess(_ code: Int) -> Bool { (200..<300).contains(code) }
    static func isClientError(_ code: Int) -> Bool { (400..<500).contains(code) }
    static func isServerError(_ code: Int) -> Bool { (500..<600).contains(code) }
}
