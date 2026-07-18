import Dependencies
import DependenciesMacros
import Foundation

/// TCA dependency facade over NeuAuth.
///
/// Register a live value at app bootstrap:
/// ```swift
/// extension NeuAuthClient: DependencyKey {
///   public static let liveValue = NeuAuthClient.live(
///     config: NeuAuthConfig(
///       issuerBaseURL: URL(string: "https://neuauth.example.app")!,
///       clientID: Secrets.neuAuthClientID,
///       scopes: "openid profile email"
///     ),
///     store: LiveKeychainStore(service: "com.example.app.neuauth")
///   )
/// }
/// ```
/// This package deliberately conforms only to `TestDependencyKey` — the app
/// owns the config, so there is no default `liveValue`.
@DependencyClient
public struct NeuAuthClient: Sendable {
    // MARK: Session lifecycle

    /// Classify launch state (valid / expired / offline / none).
    public var bootstrap: @Sendable () async -> SessionBootstrap = { .noSession }
    /// Start the proactive refresh scheduler (`exp − 120 s`).
    public var startProactiveRefresh: @Sendable () async -> Void
    /// Stop the proactive refresh scheduler.
    public var stopProactiveRefresh: @Sendable () async -> Void
    /// Tokens currently in the keychain, if any.
    public var storedTokens: @Sendable () async -> NeuAuthTokens? = { nil }
    /// Unverified claims decoded from the current access token
    /// (`sub` / `exp` / `is_anonymous` — display & scheduling only).
    public var currentClaims: @Sendable () async -> JWTClaims? = { nil }
    /// A currently-valid access token, refreshing first when needed.
    public var validAccessToken: @Sendable () async throws -> String
    /// Force a refresh now (single-flight; safe to call concurrently).
    public var refreshTokens: @Sendable () async throws -> NeuAuthTokens
    /// Persist a token set obtained out-of-band.
    public var setTokens: @Sendable (NeuAuthTokens) async throws -> Void
    /// Revoke the server session and clear stored tokens. The anonymous
    /// `device_id` is KEPT so anonymous re-create reconnects the same data.
    public var logout: @Sendable () async throws -> Void
    /// `DELETE /users/me`, then clear tokens AND the device id — after a
    /// deletion nothing should reconnect.
    public var deleteAccount: @Sendable () async throws -> Void

    // MARK: Email OTP

    /// `POST /auth/otp/send`. Use `.login` for sign-in and
    /// `.anonymousUpgrade` when proving email ownership for a merge.
    public var sendEmailCode: @Sendable (_ email: String, _ purpose: OTPPurpose) async throws -> OTPSent
    /// `POST /auth/otp/verify` — completes email sign-in and persists tokens.
    public var verifyEmailCode: @Sendable (_ email: String, _ code: String) async throws -> AuthenticatedSession

    // MARK: Anonymous

    /// `POST /auth/anonymous` — create (or reconnect, via the keychain
    /// `device_id`) an anonymous account and persist its tokens.
    public var signInAnonymously: @Sendable (_ platform: String, _ appVersion: String?) async throws -> AnonymousSession
    /// The keychain-persisted anonymous device id (created on first
    /// anonymous sign-in; survives app reinstall).
    public var anonymousDeviceID: @Sendable () async throws -> String?
    /// `POST /auth/anonymous/upgrade` — start upgrading to a registered
    /// account. Returns `.emailExists` (steer to merge) or `.otpSent`.
    public var startUpgrade: @Sendable (_ email: String) async throws -> UpgradeStart
    /// `POST /auth/anonymous/upgrade/verify` — complete the upgrade and
    /// persist the new registered-account tokens.
    public var verifyUpgrade: @Sendable (
        _ email: String, _ code: String, _ password: String?, _ displayName: String?
    ) async throws -> UpgradeComplete
    /// `POST /auth/anonymous/merge` — fold this anonymous account into the
    /// existing registered account (code sent via
    /// `sendEmailCode(_, .anonymousUpgrade)`). Persists the merged tokens.
    public var mergeIntoExistingAccount: @Sendable (
        _ targetUserID: UUID, _ code: String
    ) async throws -> MergeResult

    // MARK: WebAuthn / passkeys

    /// `POST /webauthn/register/start` (authed).
    public var webauthnRegisterStart: @Sendable (_ label: String?) async throws -> WebAuthnChallenge
    /// `POST /webauthn/register/finish` (authed) — `credential` is the
    /// webauthn-rs JSON built from the ASAuthorization result.
    public var webauthnRegisterFinish: @Sendable (
        _ challengeKey: String, _ credential: JSONValue, _ label: String?
    ) async throws -> WebAuthnCredentialInfo
    /// `POST /webauthn/authenticate/start` (pre-token).
    public var webauthnAuthenticateStart: @Sendable (_ userID: UUID?) async throws -> WebAuthnChallenge
    /// `POST /webauthn/authenticate/finish` (pre-token) — completes passkey
    /// sign-in and persists tokens.
    public var webauthnAuthenticateFinish: @Sendable (
        _ challengeKey: String, _ credential: JSONValue
    ) async throws -> AuthenticatedSession
}

// MARK: - DependencyValues

extension NeuAuthClient: TestDependencyKey {
    public static let testValue = NeuAuthClient()

    public static var previewValue: NeuAuthClient {
        let tokens = NeuAuthTokens(
            accessToken: "preview_access_token",
            refreshToken: "preview_refresh_token",
            idToken: nil,
            expiresAt: Date().addingTimeInterval(3600)
        )
        return NeuAuthClient(
            bootstrap: { .authenticated(tokens) },
            startProactiveRefresh: {},
            stopProactiveRefresh: {},
            storedTokens: { tokens },
            currentClaims: {
                JWTClaims(
                    subject: "preview_user", expiresAt: tokens.expiresAt,
                    isAnonymous: false, email: "user@example.com"
                )
            },
            validAccessToken: { tokens.accessToken },
            refreshTokens: { tokens },
            setTokens: { _ in },
            logout: {},
            deleteAccount: {},
            sendEmailCode: { _, _ in OTPSent(expiresIn: 600) },
            verifyEmailCode: { _, _ in AuthenticatedSession(tokens: tokens, user: nil) },
            signInAnonymously: { _, _ in
                AnonymousSession(userID: UUID(), isAnonymous: true, tokens: tokens)
            },
            anonymousDeviceID: { "preview-device-id" },
            startUpgrade: { email in .otpSent(email: email, expiresIn: 600) },
            verifyUpgrade: { email, _, _, displayName in
                UpgradeComplete(
                    userID: UUID(), email: email, displayName: displayName,
                    tokens: tokens, migratedItemCount: 0
                )
            },
            mergeIntoExistingAccount: { targetUserID, _ in
                MergeResult(
                    mergedInto: targetUserID, anonymousUserDeleted: true,
                    migratedItemCount: 0, tokens: tokens
                )
            },
            webauthnRegisterStart: { _ in
                WebAuthnChallenge(challengeKey: "preview", options: .object([:]))
            },
            webauthnRegisterFinish: { _, _, label in
                WebAuthnCredentialInfo(id: UUID(), label: label, backedUp: true, discoverable: true)
            },
            webauthnAuthenticateStart: { _ in
                WebAuthnChallenge(challengeKey: "preview", options: .object([:]))
            },
            webauthnAuthenticateFinish: { _, _ in
                AuthenticatedSession(tokens: tokens, user: nil)
            }
        )
    }
}

extension DependencyValues {
    public var neuAuthClient: NeuAuthClient {
        get { self[NeuAuthClient.self] }
        set { self[NeuAuthClient.self] = newValue }
    }
}
