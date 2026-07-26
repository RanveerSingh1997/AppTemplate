import Foundation

/// Header names shared between request-building and interceptor code, defined once so
/// the two sides can't drift onto slightly different string literals for the same header.
enum HeaderField {
    static let authorization = "Authorization"
    static let contentType = "Content-Type"
    /// Attached by `CorrelationIDInterceptor` to every request, and echoed in
    /// `LoggingInterceptor`'s log line — join a client log to the matching server-side
    /// request log by grepping the same ID.
    static let correlationID = "X-Correlation-ID"
}
