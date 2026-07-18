import Foundation

// MARK: - Tokens

/// The token set persisted in the keychain.
public struct NeuAuthTokens: Codable, Equatable, Sendable {
    public let accessToken: String
    public let refreshToken: String?
    public let idToken: String?
    public let expiresAt: Date

    public init(
        accessToken: String,
        refreshToken: String?,
        idToken: String?,
        expiresAt: Date
    ) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.idToken = idToken
        self.expiresAt = expiresAt
    }

    /// Expired (or within a 60 s safety margin) relative to `now`.
    public func isExpired(now: Date = Date()) -> Bool {
        now >= expiresAt.addingTimeInterval(-60)
    }

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case idToken = "id_token"
        case expiresAt = "expires_at"
    }
}

// MARK: - User

/// NeuAuth's `UserProfile` shape (returned by token grants and `/users/me`).
public struct NeuAuthUserProfile: Codable, Equatable, Sendable {
    public let id: UUID
    public let email: String?
    public let emailVerified: Bool?
    public let displayName: String?
    public let avatarURL: String?
    public let phone: String?
    public let roles: [String]?
    public let tenantID: UUID?

    public init(
        id: UUID,
        email: String?,
        emailVerified: Bool?,
        displayName: String?,
        avatarURL: String?,
        phone: String?,
        roles: [String]?,
        tenantID: UUID?
    ) {
        self.id = id
        self.email = email
        self.emailVerified = emailVerified
        self.displayName = displayName
        self.avatarURL = avatarURL
        self.phone = phone
        self.roles = roles
        self.tenantID = tenantID
    }

    enum CodingKeys: String, CodingKey {
        case id, email, phone, roles
        case emailVerified = "email_verified"
        case displayName = "display_name"
        case avatarURL = "avatar_url"
        case tenantID = "tenant_id"
    }
}

// MARK: - Token grant (server wire shape)

/// Wire shape shared by `/auth/refresh`, `/auth/otp/verify`,
/// `/webauthn/authenticate/finish`, and `/auth/register`.
struct TokenGrantResponse: Decodable {
    let accessToken: String
    let tokenType: String
    let expiresIn: Int
    let refreshToken: String?
    let idToken: String?
    let user: NeuAuthUserProfile?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
        case refreshToken = "refresh_token"
        case idToken = "id_token"
        case user
    }

    func toTokens(now: Date) -> NeuAuthTokens {
        NeuAuthTokens(
            accessToken: accessToken,
            refreshToken: refreshToken,
            idToken: idToken,
            expiresAt: now.addingTimeInterval(TimeInterval(expiresIn))
        )
    }
}

/// A completed sign-in: fresh tokens plus the user profile when the server
/// includes one.
public struct AuthenticatedSession: Equatable, Sendable {
    public let tokens: NeuAuthTokens
    public let user: NeuAuthUserProfile?

    public init(tokens: NeuAuthTokens, user: NeuAuthUserProfile?) {
        self.tokens = tokens
        self.user = user
    }
}

// MARK: - Email OTP

/// Purpose tag for `/auth/otp/send`. NeuAuth stores OTPs per-purpose, so the
/// send and verify sides must agree.
public enum OTPPurpose: String, Sendable, Equatable {
    /// Standard email sign-in (`/auth/otp/verify`).
    case login
    /// Codes consumed by anonymous upgrade *merge* (`/auth/anonymous/merge`
    /// verifies against this purpose). Used when upgrade reported
    /// `email_exists` and the user must prove ownership of the target email.
    case anonymousUpgrade = "anonymous_upgrade"
}

public struct OTPSent: Equatable, Sendable {
    /// Seconds the code stays valid.
    public let expiresIn: Int?

    public init(expiresIn: Int?) {
        self.expiresIn = expiresIn
    }
}

struct OTPSendResponse: Decodable {
    let message: String?
    let expiresIn: Int?

    enum CodingKeys: String, CodingKey {
        case message
        case expiresIn = "expires_in"
    }
}

// MARK: - Anonymous auth

/// Response of `POST /api/v1/auth/anonymous` (create or reconnect).
public struct AnonymousSession: Equatable, Sendable {
    public let userID: UUID
    public let isAnonymous: Bool
    public let tokens: NeuAuthTokens

    public init(userID: UUID, isAnonymous: Bool, tokens: NeuAuthTokens) {
        self.userID = userID
        self.isAnonymous = isAnonymous
        self.tokens = tokens
    }
}

struct AnonymousCreateResponse: Decodable {
    struct UserInfo: Decodable {
        let id: UUID
        let isAnonymous: Bool

        enum CodingKeys: String, CodingKey {
            case id
            case isAnonymous = "is_anonymous"
        }
    }

    struct WireTokens: Decodable {
        let accessToken: String
        let refreshToken: String
        let expiresIn: Int

        enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
            case refreshToken = "refresh_token"
            case expiresIn = "expires_in"
        }
    }

    let user: UserInfo
    let tokens: WireTokens

    func toSession(now: Date) -> AnonymousSession {
        AnonymousSession(
            userID: user.id,
            isAnonymous: user.isAnonymous,
            tokens: NeuAuthTokens(
                accessToken: tokens.accessToken,
                refreshToken: tokens.refreshToken,
                idToken: nil,
                expiresAt: now.addingTimeInterval(TimeInterval(tokens.expiresIn))
            )
        )
    }
}

// MARK: - Anonymous upgrade

/// Result of initiating an anonymous → registered upgrade.
///
/// `emailExists` is a **typed steering result**, not an error: the email
/// already belongs to a registered account, so the app should switch to the
/// merge flow (send an `.anonymousUpgrade` OTP to that email, then call
/// `merge(targetUserID:code:)`).
public enum UpgradeStart: Equatable, Sendable {
    case otpSent(email: String?, expiresIn: Int?)
    case emailExists(existingUserID: UUID)
}

struct UpgradeStartResponse: Decodable {
    let status: String
    let email: String?
    let expiresIn: Int?
    let existingUserID: UUID?

    enum CodingKeys: String, CodingKey {
        case status, email
        case expiresIn = "expires_in"
        case existingUserID = "existing_user_id"
    }

    func toUpgradeStart() throws -> UpgradeStart {
        switch status {
        case "otp_sent":
            return .otpSent(email: email, expiresIn: expiresIn)
        case "email_exists":
            guard let existingUserID else {
                throw NeuAuthError.decoding("email_exists response missing existing_user_id")
            }
            return .emailExists(existingUserID: existingUserID)
        default:
            throw NeuAuthError.decoding("unknown upgrade status: \(status)")
        }
    }
}

/// Response of `POST /api/v1/auth/anonymous/upgrade/verify`.
public struct UpgradeComplete: Equatable, Sendable {
    public let userID: UUID
    public let email: String
    public let displayName: String?
    public let tokens: NeuAuthTokens
    public let migratedItemCount: Int

    public init(
        userID: UUID,
        email: String,
        displayName: String?,
        tokens: NeuAuthTokens,
        migratedItemCount: Int
    ) {
        self.userID = userID
        self.email = email
        self.displayName = displayName
        self.tokens = tokens
        self.migratedItemCount = migratedItemCount
    }
}

struct UpgradeCompleteResponse: Decodable {
    struct UserInfo: Decodable {
        let id: UUID
        let email: String
        let displayName: String?

        enum CodingKeys: String, CodingKey {
            case id, email
            case displayName = "display_name"
        }
    }

    struct Migration: Decodable {
        let totalItems: Int

        enum CodingKeys: String, CodingKey {
            case totalItems = "total_items"
        }
    }

    let user: UserInfo
    let tokens: AnonymousCreateResponse.WireTokens
    let dataMigrated: Migration?

    enum CodingKeys: String, CodingKey {
        case user, tokens
        case dataMigrated = "data_migrated"
    }

    func toUpgradeComplete(now: Date) -> UpgradeComplete {
        UpgradeComplete(
            userID: user.id,
            email: user.email,
            displayName: user.displayName,
            tokens: NeuAuthTokens(
                accessToken: tokens.accessToken,
                refreshToken: tokens.refreshToken,
                idToken: nil,
                expiresAt: now.addingTimeInterval(TimeInterval(tokens.expiresIn))
            ),
            migratedItemCount: dataMigrated?.totalItems ?? 0
        )
    }
}

// MARK: - Merge

/// Response of `POST /api/v1/auth/anonymous/merge` — the anonymous account's
/// data was transferred into the existing registered account, and the
/// returned tokens now belong to that registered account.
public struct MergeResult: Equatable, Sendable {
    public let mergedInto: UUID
    public let anonymousUserDeleted: Bool
    public let migratedItemCount: Int
    public let tokens: NeuAuthTokens

    public init(
        mergedInto: UUID,
        anonymousUserDeleted: Bool,
        migratedItemCount: Int,
        tokens: NeuAuthTokens
    ) {
        self.mergedInto = mergedInto
        self.anonymousUserDeleted = anonymousUserDeleted
        self.migratedItemCount = migratedItemCount
        self.tokens = tokens
    }
}

struct MergeResponse: Decodable {
    let mergedInto: UUID
    let anonymousUserDeleted: Bool
    let dataMigrated: UpgradeCompleteResponse.Migration?
    let tokens: AnonymousCreateResponse.WireTokens

    enum CodingKeys: String, CodingKey {
        case tokens
        case mergedInto = "merged_into"
        case anonymousUserDeleted = "anonymous_user_deleted"
        case dataMigrated = "data_migrated"
    }

    func toMergeResult(now: Date) -> MergeResult {
        MergeResult(
            mergedInto: mergedInto,
            anonymousUserDeleted: anonymousUserDeleted,
            migratedItemCount: dataMigrated?.totalItems ?? 0,
            tokens: NeuAuthTokens(
                accessToken: tokens.accessToken,
                refreshToken: tokens.refreshToken,
                idToken: nil,
                expiresAt: now.addingTimeInterval(TimeInterval(tokens.expiresIn))
            )
        )
    }
}

// MARK: - WebAuthn

/// A WebAuthn challenge from `register/start` or `authenticate/start`.
/// `options` is the raw `webauthn-rs` JSON (`CreationChallengeResponse` /
/// `RequestChallengeResponse`) passed through untouched — binary fields are
/// base64url strings for an `ASAuthorization` client to map.
public struct WebAuthnChallenge: Equatable, Sendable {
    public let challengeKey: String
    public let options: JSONValue

    public init(challengeKey: String, options: JSONValue) {
        self.challengeKey = challengeKey
        self.options = options
    }
}

struct WebAuthnChallengeResponse: Decodable {
    let challengeKey: String
    let options: JSONValue

    enum CodingKeys: String, CodingKey {
        case options
        case challengeKey = "challenge_key"
    }
}

/// Stored-credential metadata returned by `register/finish` and
/// `GET /webauthn/credentials`.
public struct WebAuthnCredentialInfo: Equatable, Sendable {
    public let id: UUID
    public let label: String?
    public let backedUp: Bool
    public let discoverable: Bool

    public init(id: UUID, label: String?, backedUp: Bool, discoverable: Bool) {
        self.id = id
        self.label = label
        self.backedUp = backedUp
        self.discoverable = discoverable
    }
}

struct WebAuthnCredentialWire: Decodable {
    let id: UUID
    let label: String?
    let backedUp: Bool
    let discoverable: Bool

    enum CodingKeys: String, CodingKey {
        case id, label, discoverable
        case backedUp = "backed_up"
    }

    var info: WebAuthnCredentialInfo {
        WebAuthnCredentialInfo(id: id, label: label, backedUp: backedUp, discoverable: discoverable)
    }
}

struct WebAuthnRegisterFinishResponse: Decodable {
    let credential: WebAuthnCredentialWire
}

// MARK: - Session bootstrap

/// Classification of app-launch session state — Vozla's outage-vs-401 rule:
/// only an explicit server 401 kills the session; a transport failure keeps
/// the user in their local session (`offline`) instead of bouncing them to
/// login during an outage.
public enum SessionBootstrap: Equatable, Sendable {
    /// No stored tokens at all (fresh install / after logout).
    case noSession
    /// Valid session — tokens are usable (refreshed just now if needed).
    case authenticated(NeuAuthTokens)
    /// The server explicitly rejected the refresh token (401): the session is
    /// dead. Stored tokens are cleared; the anonymous `device_id` is kept so
    /// an anonymous re-create reconnects the same account.
    case expired
    /// Could not reach the server. Local tokens (possibly stale) are kept —
    /// treat the user as signed-in and retry later.
    case offline(NeuAuthTokens?)
}
