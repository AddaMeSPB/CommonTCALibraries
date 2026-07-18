import Foundation

/// Locally-decoded JWT claims — **unverified**.
///
/// The signature is NOT checked; this exists only for display and refresh
/// scheduling (reading `exp` / `is_anonymous` / `sub` off the access token).
/// Never make an authorization decision from these values — the server is the
/// authority and will reject a forged token anyway.
public struct JWTClaims: Sendable, Equatable {
    /// `sub` claim — the NeuAuth user id.
    public let subject: String?
    /// `exp` claim as a `Date`.
    public let expiresAt: Date?
    /// `is_anonymous` claim. NeuAuth emits `true` for anonymous users and
    /// omits the claim entirely for registered users, so absent == `false`.
    public let isAnonymous: Bool
    /// `email` claim when present.
    public let email: String?

    public init(subject: String?, expiresAt: Date?, isAnonymous: Bool, email: String?) {
        self.subject = subject
        self.expiresAt = expiresAt
        self.isAnonymous = isAnonymous
        self.email = email
    }

    /// Decode the payload segment of a JWT without verifying the signature.
    /// Returns `nil` if the token is not a structurally valid JWT.
    public init?(unverifiedJWT token: String) {
        let segments = token.split(separator: ".")
        guard segments.count == 3,
              let payloadData = Self.base64URLDecode(String(segments[1])),
              let json = try? JSONSerialization.jsonObject(with: payloadData),
              let payload = json as? [String: Any]
        else { return nil }

        self.subject = payload["sub"] as? String
        if let exp = payload["exp"] as? TimeInterval {
            self.expiresAt = Date(timeIntervalSince1970: exp)
        } else {
            self.expiresAt = nil
        }
        self.isAnonymous = payload["is_anonymous"] as? Bool ?? false
        self.email = payload["email"] as? String
    }

    /// Seconds until `exp` minus `buffer`, measured from `now`.
    /// Returns 0 if already inside the buffer window (or `exp` is missing).
    public func secondsUntilExpiry(buffer: TimeInterval, now: Date = Date()) -> TimeInterval {
        guard let expiresAt else { return 0 }
        return max(0, expiresAt.timeIntervalSince(now) - buffer)
    }

    static func base64URLDecode(_ value: String) -> Data? {
        var base64 = value
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while base64.count % 4 != 0 { base64.append("=") }
        return Data(base64Encoded: base64)
    }
}
