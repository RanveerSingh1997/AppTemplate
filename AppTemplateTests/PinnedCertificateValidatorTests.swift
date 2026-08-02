@testable import AppTemplate
import Foundation
import Security
import Testing

/// Exercises `PinnedCertificateValidator.publicKeyHash(for:)` — the actual security-critical
/// logic (extract the server's public key, SHA-256 it, base64-encode it) — against a real
/// `SecTrust` built from a throwaway, offline test certificate. Not testing
/// `urlSession(_:didReceive:completionHandler:)`'s accept/reject dispatch directly: a real
/// `URLAuthenticationChallenge` with a working `serverTrust` can only be produced by an
/// actual TLS handshake, not constructed synthetically, so that's exercised by
/// `PinnedCertificateValidator` being wired into `URLSessionAPIClient.makeSession` and used
/// against a real backend — not something a fast, offline unit test can cover.
struct PinnedCertificateValidatorTests {
    // A throwaway, self-signed certificate generated for this test only (`openssl req -x509
    // -newkey rsa:2048 -days 3650 -nodes -subj "/CN=test.apptemplate.local"`) — not a real
    // pin for a real backend, just a fixture with a known public key.
    private static let testCertificateDER = """
    MIICvjCCAaYCCQDlySb1OgMxsDANBgkqhkiG9w0BAQsFADAhMR8wHQYDVQQDDBZ0\
    ZXN0LmFwcHRlbXBsYXRlLmxvY2FsMB4XDTI2MDgwMjA3MDEwOFoXDTM2MDczMDA3\
    MDEwOFowITEfMB0GA1UEAwwWdGVzdC5hcHB0ZW1wbGF0ZS5sb2NhbDCCASIwDQYJ\
    KoZIhvcNAQEBBQADggEPADCCAQoCggEBALN5OxE+flZT4uBZHFN6bgpskpinP6wJ\
    DaXhfpyLXRZ+Sl+7zSRXDy3lBqoXHeErtFYQnx5EoQzm2PepyYLQvngzP7Z0Ake+\
    FopCXJE+fIXezH2657A08hdiEktNN9kJI9Sj/KWAM7KqQ281iWrmfHomUrft/TI2\
    EoSIwcrl2uTM1OR1TzE7FrUjICPlQ3vkMSmbyG0GJKdyxbNUIrnlR9SLUqtjr5a6\
    tvF6eLqqEm14WOVo0owBxY1eCks9FLj3uNlSUzERsO+ZtwT62tGnyGljg0l0gaky\
    QdgYf7mAnpQ2OND+VpH14jNV7PzjL3VFvXctCmoD8CbfcaqArs42gIkCAwEAATAN\
    BgkqhkiG9w0BAQsFAAOCAQEAJSJ0BtyKoARwC7/4098kqsgICi/rGRBBXCxp/iLp\
    g7kLT0Ur9L9Hh0/P8hNa2sI+rITS2ojlQLexXBScMbUiyCvZ3tkjPJwW+rTFQBQe\
    MDC7VBVQm4qugzJ5wYLuhd9idGLqhBj9VqhKsgW+iYP1STvL1iPdbHkWscpaoE+2\
    34J2p8hiRacSeX745Et5SzTL0+7t38ts2VWX1o8VXPcObUyhbDf2WJBXx96ipePb\
    Xv2Ii07QqLw9BbFC9gSOQ/lcqAhgC1E2AyqqHoJ9a3Ip+S0ARJCXtPA/UJEfXSTe\
    1g2LujViQhfl0xbD6dh0BSXGAABkT1oTGg0l/UmRO2ve+g==
    """

    // Computed independently via the exact (corrected) pipeline the class's own doc
    // comment documents (`openssl rsa -pubin -RSAPublicKey_out -outform der | openssl dgst
    // -sha256 -binary | openssl enc -base64`), not derived from the code under test.
    private static let expectedPublicKeyHash = "VvLNlEC4worRBaFhq8KtvTgPuvNew9TT1pYNMRe8Fn8="

    // What the *more commonly suggested* (and wrong, for this purpose) recipe computes —
    // `openssl pkey -pubin -outform der` instead of `-RSAPublicKey_out` — i.e. the
    // SubjectPublicKeyInfo encoding rather than raw PKCS#1. This test existing at all is
    // what caught that the doc comment originally documented this recipe by mistake: it
    // hashes real bytes from the same real key, just not the ones
    // `SecKeyCopyExternalRepresentation` actually returns, so pinning built from it would
    // have rejected every connection to a real backend.
    private static let spkiEncodedPublicKeyHash = "rn75i/+DMS0vTuWDGlBBvjnx3ZhKYQA9dfRCYyJrUos="

    private func makeTestServerTrust() throws -> SecTrust {
        let derString = Self.testCertificateDER.replacingOccurrences(of: "\n", with: "")
        let der = try #require(Data(base64Encoded: derString))
        let certificate = try #require(SecCertificateCreateWithData(nil, der as CFData))

        var trust: SecTrust?
        let status = SecTrustCreateWithCertificates(certificate, SecPolicyCreateBasicX509(), &trust)
        try #require(status == errSecSuccess)
        return try #require(trust)
    }

    @Test
    func publicKeyHashMatchesTheIndependentlyComputedOpenSSLHash() throws {
        let trust = try makeTestServerTrust()
        #expect(PinnedCertificateValidator.publicKeyHash(for: trust) == Self.expectedPublicKeyHash)
    }

    @Test
    func publicKeyHashDoesNotMatchTheSPKIEncodedHash() throws {
        let trust = try makeTestServerTrust()
        #expect(PinnedCertificateValidator.publicKeyHash(for: trust) != Self.spkiEncodedPublicKeyHash)
    }
}
