import Foundation
import os

extension NeuAuthClient {
    /// Build a live client over a `URLSession`. The `AuthSession` actor owns
    /// all token state; construct ONE live client per app and register it as
    /// your `liveValue`.
    public static func live(
        config: NeuAuthConfig,
        store: any KeychainStore,
        urlSession: URLSession = .shared
    ) -> NeuAuthClient {
        live(session: AuthSession(config: config, store: store, urlSession: urlSession))
    }

    /// Build a live client over an existing `AuthSession` (advanced: lets the
    /// app share the session with non-TCA call sites, or tests inject a
    /// scripted transport/clock).
    public static func live(session: AuthSession) -> NeuAuthClient {
        let logger = Logger(
            subsystem: Bundle.main.bundleIdentifier ?? "NeuAuthKit",
            category: "NeuAuthClient"
        )

        @Sendable func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
            do {
                return try NeuAuthJSON.decoder().decode(T.self, from: data)
            } catch {
                throw NeuAuthError.decoding("decoding \(T.self): \(error)")
            }
        }

        return NeuAuthClient(
            bootstrap: {
                await session.bootstrap()
            },
            startProactiveRefresh: {
                await session.startProactiveRefresh()
            },
            stopProactiveRefresh: {
                await session.stopProactiveRefresh()
            },
            storedTokens: {
                await session.storedTokens()
            },
            currentClaims: {
                await session.currentClaims()
            },
            validAccessToken: {
                try await session.validAccessToken()
            },
            refreshTokens: {
                try await session.refreshTokens()
            },
            setTokens: { tokens in
                try await session.setTokens(tokens)
            },
            logout: {
                // Best-effort server revocation; local sign-out must succeed
                // even when the network is down. device_id is kept.
                if let refreshToken = await session.storedTokens()?.refreshToken {
                    do {
                        _ = try await session.send(.logout(refreshToken: refreshToken))
                    } catch {
                        logger.warning(
                            "Logout revocation failed (clearing local tokens anyway): \(String(describing: error), privacy: .private)"
                        )
                    }
                }
                await session.stopProactiveRefresh()
                try await session.clearTokens()
            },
            deleteAccount: {
                // Capture the deleted session's generation so a session that
                // lands mid-flight (rare, but possible) is never signed out
                // by the post-success cleanup below. Token rotation during
                // the request keeps the generation, so cleanup still runs.
                let generation = await session.currentSessionGeneration()
                do {
                    _ = try await session.send(.deleteAccount())
                } catch NeuAuthError.notFound {
                    // Already deleted server-side (e.g. the DELETE committed
                    // but the response was lost) — idempotent success; fall
                    // through to the local wipe.
                } catch NeuAuthError.unauthorized {
                    // The SESSION is dead — that does NOT mean the DELETE
                    // executed. The account may still exist server-side, and
                    // for an anonymous user the device_id is the only way
                    // back in (sign in anonymously again → real delete). So:
                    // keep device_id, stop the scheduler, and rethrow so the
                    // caller knows deletion did not happen.
                    await session.stopProactiveRefresh()
                    throw NeuAuthError.unauthorized
                } // Transport/other errors rethrow: account still exists,
                  // keep local state so the user can retry.
                // CAS cleanup: only wipe if the deleted session is still the
                // current one; a replacement session (and its scheduler)
                // survives untouched.
                if try await session.clearTokensIfGenerationMatches(generation) {
                    await session.stopProactiveRefresh()
                    // Account is gone — its device id must not reconnect.
                    try await session.clearDeviceID()
                }
            },
            sendEmailCode: { email, purpose in
                let data = try await session.send(.otpSend(email: email, purpose: purpose))
                let response = try decode(OTPSendResponse.self, from: data)
                return OTPSent(expiresIn: response.expiresIn)
            },
            verifyEmailCode: { email, code in
                let data = try await session.send(.otpVerify(email: email, code: code))
                let grant = try decode(TokenGrantResponse.self, from: data)
                let tokens = grant.toTokens(now: session.currentDate())
                try await session.setTokens(tokens)
                return AuthenticatedSession(tokens: tokens, user: grant.user)
            },
            signInAnonymously: { platform, appVersion in
                let deviceID = try await session.loadOrCreateDeviceID()
                let data = try await session.send(
                    .anonymousCreate(deviceID: deviceID, platform: platform, appVersion: appVersion)
                )
                let response = try decode(AnonymousCreateResponse.self, from: data)
                let anonymous = response.toSession(now: session.currentDate())
                try await session.setTokens(anonymous.tokens)
                return anonymous
            },
            anonymousDeviceID: {
                try await session.loadDeviceID()
            },
            startUpgrade: { email in
                let data = try await session.send(.upgradeStart(email: email))
                let response = try decode(UpgradeStartResponse.self, from: data)
                return try response.toUpgradeStart()
            },
            verifyUpgrade: { email, code, password, displayName in
                let data = try await session.send(
                    .upgradeVerify(
                        email: email, code: code, password: password, displayName: displayName
                    )
                )
                let response = try decode(UpgradeCompleteResponse.self, from: data)
                let complete = response.toUpgradeComplete(now: session.currentDate())
                try await session.setTokens(complete.tokens)
                // The anonymous identity ended with this upgrade. Retire its
                // device id so a future "continue as guest" mints a CLEAN
                // anonymous account instead of reconnecting an id that now
                // belongs to a registered user. Best-effort: the upgrade
                // already succeeded server-side and locally — a keychain
                // hiccup here must not surface as an operation failure.
                do {
                    try await session.clearDeviceID()
                } catch {
                    logger.warning("Failed to retire anonymous device_id after upgrade")
                }
                return complete
            },
            mergeIntoExistingAccount: { targetUserID, code in
                let data = try await session.send(.merge(targetUserID: targetUserID, code: code))
                let response = try decode(MergeResponse.self, from: data)
                let result = response.toMergeResult(now: session.currentDate())
                try await session.setTokens(result.tokens)
                // The anonymous account was folded into (and deleted from)
                // the registered one — its device id must not reconnect
                // anything. A later guest sign-in starts fresh. Best-effort:
                // the merge already succeeded.
                do {
                    try await session.clearDeviceID()
                } catch {
                    logger.warning("Failed to retire anonymous device_id after merge")
                }
                return result
            },
            webauthnRegisterStart: { label in
                let data = try await session.send(.webauthnRegisterStart(label: label))
                let response = try decode(WebAuthnChallengeResponse.self, from: data)
                return WebAuthnChallenge(
                    challengeKey: response.challengeKey, options: response.options
                )
            },
            webauthnRegisterFinish: { challengeKey, credential, label in
                let data = try await session.send(
                    .webauthnRegisterFinish(
                        challengeKey: challengeKey, credential: credential, label: label
                    )
                )
                let response = try decode(WebAuthnRegisterFinishResponse.self, from: data)
                return response.credential.info
            },
            webauthnAuthenticateStart: { userID in
                let data = try await session.send(.webauthnAuthenticateStart(userID: userID))
                let response = try decode(WebAuthnChallengeResponse.self, from: data)
                return WebAuthnChallenge(
                    challengeKey: response.challengeKey, options: response.options
                )
            },
            webauthnAuthenticateFinish: { challengeKey, credential in
                let data = try await session.send(
                    .webauthnAuthenticateFinish(challengeKey: challengeKey, credential: credential)
                )
                let grant = try decode(TokenGrantResponse.self, from: data)
                let tokens = grant.toTokens(now: session.currentDate())
                try await session.setTokens(tokens)
                return AuthenticatedSession(tokens: tokens, user: grant.user)
            }
        )
    }
}

// MARK: - Session helpers used by the live client

extension AuthSession {
    /// The session's injected `now` (test-controllable). `now` is an
    /// immutable `@Sendable` closure, so this is safely nonisolated.
    nonisolated func currentDate() -> Date {
        now()
    }

    func loadDeviceID() throws -> String? {
        try store.loadDeviceID()
    }

    func loadOrCreateDeviceID() throws -> String {
        try store.loadOrCreateDeviceID()
    }

    func clearDeviceID() throws {
        try store.clearDeviceID()
    }
}
