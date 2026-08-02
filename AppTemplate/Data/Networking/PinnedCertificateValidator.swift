import CryptoKit
import Foundation

/// SSL pinning by server public key SHA-256 hash (survives certificate renewal, unlike
/// pinning the whole certificate, as long as the key isn't rotated). Disabled by default —
/// `URLSessionAPIClient.makeSession` only installs this when you pass non-empty
/// `pinnedPublicKeyHashes`, since a template can't ship real hashes for a real backend.
///
/// To get your API's hash (RSA key — for an EC key, extract the X9.63 point instead of
/// using `-RSAPublicKey_out`): `openssl s_client -connect your-host:443 </dev/null 2>/dev/null
/// | openssl x509 -pubkey -noout | openssl rsa -pubin -RSAPublicKey_out -outform der |
/// openssl dgst -sha256 -binary | openssl enc -base64`. **Must** be `-RSAPublicKey_out`,
/// not the more commonly-suggested `openssl pkey -pubin -outform der` — that produces the
/// SubjectPublicKeyInfo (SPKI) encoding, a different (and larger) byte sequence than the
/// raw PKCS#1 `RSAPublicKey` bytes `SecKeyCopyExternalRepresentation` returns below, so it
/// hashes to a value that will never match at runtime and silently rejects every
/// connection. Verified against `SecKeyCopyExternalRepresentation`'s actual output in
/// `AppTemplateTests/PinnedCertificateValidatorTests.swift` — the SPKI-encoded command is
/// wrong specifically because it doesn't match what this file computes, not a matter of
/// preference between two valid recipes.
final class PinnedCertificateValidator: NSObject, URLSessionDelegate, @unchecked Sendable {
    private let pinnedPublicKeyHashes: Set<String>

    init(pinnedPublicKeyHashes: Set<String>) {
        self.pinnedPublicKeyHashes = pinnedPublicKeyHashes
    }

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let serverTrust = challenge.protectionSpace.serverTrust,
              let hash = Self.publicKeyHash(for: serverTrust) else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        if pinnedPublicKeyHashes.contains(hash) {
            completionHandler(.useCredential, URLCredential(trust: serverTrust))
        } else {
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }

    /// Internal, not private, so `PinnedCertificateValidatorTests` can feed it a `SecTrust`
    /// built from a fixture certificate — this is the actual security-critical logic (key
    /// extraction + hashing); `urlSession(_:didReceive:completionHandler:)`'s accept/reject
    /// dispatch around it is a one-line `Set.contains` check once this value exists.
    static func publicKeyHash(for serverTrust: SecTrust) -> String? {
        guard let certificates = SecTrustCopyCertificateChain(serverTrust) as? [SecCertificate],
              let certificate = certificates.first,
              let publicKey = SecCertificateCopyKey(certificate),
              let publicKeyData = SecKeyCopyExternalRepresentation(publicKey, nil) as Data? else {
            return nil
        }
        return Data(SHA256.hash(data: publicKeyData)).base64EncodedString()
    }
}
