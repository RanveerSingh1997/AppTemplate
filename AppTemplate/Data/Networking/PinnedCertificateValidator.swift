import CryptoKit
import Foundation

/// SSL pinning by server public key SHA-256 hash (survives certificate renewal, unlike
/// pinning the whole certificate, as long as the key isn't rotated). Disabled by default —
/// `URLSessionAPIClient.makeSession` only installs this when you pass non-empty
/// `pinnedPublicKeyHashes`, since a template can't ship real hashes for a real backend.
///
/// To get your API's hash: `openssl s_client -connect your-host:443 | openssl x509
/// -pubkey -noout | openssl pkey -pubin -outform der | openssl dgst -sha256 -binary |
/// openssl enc -base64`
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

    private static func publicKeyHash(for serverTrust: SecTrust) -> String? {
        guard let certificates = SecTrustCopyCertificateChain(serverTrust) as? [SecCertificate],
              let certificate = certificates.first,
              let publicKey = SecCertificateCopyKey(certificate),
              let publicKeyData = SecKeyCopyExternalRepresentation(publicKey, nil) as Data? else {
            return nil
        }
        return Data(SHA256.hash(data: publicKeyData)).base64EncodedString()
    }
}
