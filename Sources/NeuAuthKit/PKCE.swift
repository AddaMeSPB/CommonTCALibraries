import CryptoKit
import Foundation

// MARK: - PKCE (RFC 7636)

/// PKCE verifier/challenge generation for OAuth2 authorization-code flows.
/// Ported from Vozla's hardened implementation (RFC 7636 S256).
public enum PKCE {
    public struct Params: Sendable, Equatable {
        public let codeVerifier: String
        public let codeChallenge: String

        public init(codeVerifier: String, codeChallenge: String) {
            self.codeVerifier = codeVerifier
            self.codeChallenge = codeChallenge
        }
    }

    /// Generate a fresh PKCE verifier+challenge pair.
    public static func generate() -> Params {
        let verifier = generateCodeVerifier()
        let challenge = challenge(for: verifier)
        return Params(codeVerifier: verifier, codeChallenge: challenge)
    }

    /// Compute the S256 challenge for a given verifier:
    /// `challenge = base64url( SHA256(verifier) )`
    public static func challenge(for verifier: String) -> String {
        let data = Data(verifier.utf8)
        let hash = SHA256.hash(data: data)
        return base64URLEncode(Data(hash))
    }

    static func generateCodeVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        if status != errSecSuccess {
            // SecRandomCopyBytes essentially cannot fail on Apple platforms,
            // but never proceed with an all-zero verifier if it somehow does.
            bytes = (0..<32).map { _ in UInt8.random(in: .min ... .max) }
        }
        let encoded = base64URLEncode(Data(bytes))
        // RFC 7636: 43..128 chars. base64url of 32 bytes is 43 chars (no padding).
        return String(encoded.prefix(43))
    }

    static func base64URLEncode(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
