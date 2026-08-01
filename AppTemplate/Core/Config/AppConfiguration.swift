import Foundation

/// Reads build-time configuration out of Info.plist (populated per-environment from the
/// Dev/QA/Prod xcconfig files via project.yml's `target.info.properties` block).
///
/// In dev a missing key falls back to a safe default so the app is always runnable without
/// extra setup; in QA/Prod a missing key throws instead of crashing, so a bad build
/// surfaces as a caught startup error rather than a fatalError.
enum AppConfiguration {
    static func string(forKey key: String, developmentDefault: String) throws -> String {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String, !value.isEmpty else {
            if AppEnvironment.current == .dev {
                return developmentDefault
            }
            throw AppError.configuration(
                "Missing required configuration key: \(key). Set it in the environment's xcconfig file."
            )
        }
        return value
    }

    static func apiBaseURL() throws -> URL {
        let raw = try string(forKey: "APIBaseURL", developmentDefault: "https://dev-api.example.com")
        return try parseAPIBaseURL(raw)
    }

    /// Separated from `apiBaseURL()` so the un-escaping logic is testable without a
    /// `Bundle.main` backing it — the xcconfig files escape "//" as "\/\/" (an unescaped
    /// "//" starts a comment in xcconfig syntax), and Info.plist variable substitution
    /// copies that value through verbatim rather than un-escaping it, so it has to be
    /// un-escaped here instead.
    static func parseAPIBaseURL(_ raw: String) throws -> URL {
        let unescaped = raw.replacingOccurrences(of: "\\/", with: "/")
        guard let url = URL(string: unescaped), url.host != nil else {
            throw AppError.configuration("APIBaseURL is not a valid URL: \(raw)")
        }
        return url
    }
}
