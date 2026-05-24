import Crypto
import Foundation

/// PKCE (Proof Key for Code Exchange, RFC 7636) helpers for OAuth.
///
/// Generates a cryptographically random `code_verifier` and the matching
/// SHA-256 `code_challenge` (base64url-encoded, no padding).
public enum PKCE {

    /// A generated PKCE pair: the secret `verifier` (kept by the client) and
    /// the `challenge` (sent in the authorize URL).
    public struct Pair: Sendable, Equatable {
        public let verifier: String
        public let challenge: String
        public let method: String   // always "S256"

        public init(verifier: String, challenge: String, method: String = "S256") {
            self.verifier = verifier
            self.challenge = challenge
            self.method = method
        }
    }

    /// Generate a fresh verifier+challenge pair using 32 random bytes (≥43 chars
    /// after base64url, satisfying RFC 7636 §4.1).
    public static func generate() -> Pair {
        var bytes = [UInt8](repeating: 0, count: 32)
        for i in 0..<bytes.count {
            bytes[i] = UInt8.random(in: 0...255)
        }
        let verifier = Data(bytes).base64URLEncodedString()
        let digest = SHA256.hash(data: Data(verifier.utf8))
        let challenge = Data(digest).base64URLEncodedString()
        return Pair(verifier: verifier, challenge: challenge)
    }

    /// Generate a random URL-safe state token (for CSRF protection).
    public static func generateState(byteCount: Int = 24) -> String {
        var bytes = [UInt8](repeating: 0, count: byteCount)
        for i in 0..<bytes.count {
            bytes[i] = UInt8.random(in: 0...255)
        }
        return Data(bytes).base64URLEncodedString()
    }
}

// MARK: - Base64 URL Encoding

public extension Data {
    /// RFC 4648 §5 base64url, no padding.
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
