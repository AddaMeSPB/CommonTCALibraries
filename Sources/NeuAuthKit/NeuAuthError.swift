import Foundation

/// Typed errors surfaced by NeuAuthKit.
///
/// HTTP status codes are mapped per-endpoint: a 401 on `otp/verify` means
/// "wrong or expired code" (`.invalidOrExpiredCode`), while a 401 on an
/// authed endpoint *after* a refresh + retry means the session is dead
/// (`.unauthorized`). Callers should never need to inspect raw statuses.
public enum NeuAuthError: Error, Equatable, Sendable {
    /// No stored credentials (no tokens in the keychain).
    case notAuthenticated
    /// The session is invalid: the server rejected both the access token and
    /// a refresh attempt (or the refresh token itself).
    case unauthorized
    /// A verification code was wrong or expired (401 on an OTP-verify-style
    /// endpoint — NOT a session problem).
    case invalidOrExpiredCode
    /// 429 from the server. `retryAfterSeconds` when the envelope carries it.
    case rateLimited(retryAfterSeconds: Int?)
    /// 400 with the NeuAuth `{ "error": code, "message": … }` envelope.
    case badRequest(code: String?, message: String?)
    /// 403 with the NeuAuth envelope.
    case forbidden(code: String?, message: String?)
    case notFound
    case conflict(message: String?)
    /// Any other non-2xx status.
    case server(status: Int, message: String?)
    /// Networking failure (DNS, timeout, connection refused, …). The request
    /// never received an HTTP response — distinct from any server rejection.
    case transport(String)
    /// The response body did not decode as expected.
    case decoding(String)
    /// Keychain read/write failed. `status` is the `OSStatus` when available.
    case keychain(status: Int32?)
}

extension NeuAuthError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .notAuthenticated: return "Not signed in"
        case .unauthorized: return "Session expired — please sign in again"
        case .invalidOrExpiredCode: return "Invalid or expired verification code"
        case .rateLimited: return "Too many attempts — please try again later"
        case .badRequest(_, let message): return message ?? "Invalid request"
        case .forbidden(_, let message): return message ?? "Not allowed"
        case .notFound: return "Not found"
        case .conflict(let message): return message ?? "Conflict"
        case .server(let status, let message): return message ?? "Server error (\(status))"
        case .transport: return "Network error — check your connection"
        case .decoding: return "Unexpected server response"
        case .keychain: return "Failed to access secure storage"
        }
    }
}

/// NeuAuth's flat error envelope: `{ "error": "<code>", "message": "<text>" }`.
/// (See `neuauth/server/src/error.rs — IntoResponse for AppError`.)
struct NeuAuthErrorEnvelope: Decodable {
    let error: String?
    let message: String?
    let retryAfter: Int?

    enum CodingKeys: String, CodingKey {
        case error, message
        case retryAfter = "retry_after"
    }
}
