import Clocks
import Foundation
import os

/// Token lifecycle owner: single-flight refresh, 401-retry-once transport,
/// proactive expiry-scheduled refresh, and launch bootstrap classification.
///
/// Semantics (ported from Vozla's `Transport` actor + eCardify's proactive
/// scheduler, unified so they cannot race):
///
/// * **Single in-flight refresh.** Concurrent callers that all hit 401 await
///   the SAME refresh task instead of each firing their own POST to
///   `/auth/refresh`. With refresh-token rotation, parallel refreshes would
///   invalidate each other and log the user out of a valid session.
/// * **Reactive 401 → refresh → retry once.** A second 401 after a fresh
///   token means the session is dead → `NeuAuthError.unauthorized`.
/// * **Proactive refresh at `exp − 120 s`** (eCardify pattern), funneled
///   through the same single-flight task as the reactive path.
/// * **Pre-token endpoints bypass** the bearer/refresh machinery entirely —
///   a 401 there means "wrong code", not "refresh time".
/// * **Outage vs 401 (bootstrap).** Only an explicit server rejection kills
///   the session; transport failures classify as `.offline` so users aren't
///   bounced to login during a server outage.
public actor AuthSession {
    /// Transport hook: injectable for tests; live value wraps `URLSession`.
    public typealias DataHandler = @Sendable (URLRequest) async throws -> (Data, HTTPURLResponse)

    let config: NeuAuthConfig
    let store: any KeychainStore
    let http: DataHandler
    let clock: any Clock<Duration>
    let now: @Sendable () -> Date

    private var refreshTask: Task<NeuAuthTokens, Error>?
    private var proactiveTask: Task<Void, Never>?

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "NeuAuthKit",
        category: "AuthSession"
    )

    public init(
        config: NeuAuthConfig,
        store: any KeychainStore,
        http: @escaping DataHandler,
        clock: any Clock<Duration> = ContinuousClock(),
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.config = config
        self.store = store
        self.http = http
        self.clock = clock
        self.now = now
    }

    /// Convenience live init over a `URLSession`.
    public init(config: NeuAuthConfig, store: any KeychainStore, urlSession: URLSession = .shared) {
        self.init(
            config: config,
            store: store,
            http: { request in
                let (data, response) = try await urlSession.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw NeuAuthError.transport("non-HTTP response")
                }
                return (data, httpResponse)
            }
        )
    }

    deinit {
        proactiveTask?.cancel()
    }

    // MARK: - Token accessors

    public func storedTokens() -> NeuAuthTokens? {
        try? store.loadTokens()
    }

    /// Persist a fresh token set (after OTP verify, anonymous create,
    /// upgrade, merge, or WebAuthn sign-in).
    public func setTokens(_ tokens: NeuAuthTokens) throws {
        try store.saveTokens(tokens)
    }

    /// Clear tokens only — the anonymous `device_id` survives so a later
    /// anonymous create reconnects the same account.
    public func clearTokens() throws {
        try store.clearTokens()
    }

    /// Unverified claims off the current access token (display/scheduling only).
    public func currentClaims() -> JWTClaims? {
        guard let tokens = try? store.loadTokens() else { return nil }
        return JWTClaims(unverifiedJWT: tokens.accessToken)
    }

    /// A currently-valid access token, refreshing (single-flight) if the
    /// stored one is expired or inside its 60 s safety margin.
    public func validAccessToken() async throws -> String {
        guard let tokens = try store.loadTokens() else {
            throw NeuAuthError.notAuthenticated
        }
        guard tokens.isExpired(now: now()) else { return tokens.accessToken }
        return try await refreshTokens().accessToken
    }

    // MARK: - Refresh (single-flight)

    /// Refresh the session and persist the new tokens. Concurrent callers
    /// are deduplicated onto one in-flight request.
    @discardableResult
    public func refreshTokens() async throws -> NeuAuthTokens {
        if let inFlight = refreshTask {
            return try await inFlight.value
        }
        let task = Task<NeuAuthTokens, Error> { [config, store, http, now] in
            guard let refreshToken = (try? store.loadTokens())?.refreshToken else {
                throw NeuAuthError.notAuthenticated
            }
            let api = APIRequest.refresh(refreshToken: refreshToken)
            let request = api.urlRequest(config: config, accessToken: nil)
            let (data, response) = try await Self.perform(http, request)
            switch response.statusCode {
            case 200...299:
                let grant: TokenGrantResponse
                do {
                    grant = try NeuAuthJSON.decoder().decode(TokenGrantResponse.self, from: data)
                } catch {
                    throw NeuAuthError.decoding("refresh response: \(error)")
                }
                let tokens = grant.toTokens(now: now())
                try store.saveTokens(tokens)
                return tokens
            case 401, 403:
                // The server explicitly rejected the session (revoked,
                // rotated-away, or account suspended) — it is dead.
                throw NeuAuthError.unauthorized
            default:
                throw ResponseMapper.error(
                    status: response.statusCode, data: data, unauthorizedSemantics: .session
                )
            }
        }
        refreshTask = task
        defer { refreshTask = nil }
        do {
            let tokens = try await task.value
            logger.debug("Token refresh succeeded")
            return tokens
        } catch {
            logger.warning("Token refresh failed: \(String(describing: error), privacy: .public)")
            throw error
        }
    }

    // MARK: - Transport

    /// Send an API request. Authed requests get the bearer token, a local
    /// pre-expiry refresh, and the 401 → refresh → retry-once dance.
    /// Pre-token requests bypass all of it.
    func send(_ api: APIRequest) async throws -> Data {
        if !api.requiresAuth {
            let (data, response) = try await Self.perform(
                http, api.urlRequest(config: config, accessToken: nil)
            )
            guard (200...299).contains(response.statusCode) else {
                throw ResponseMapper.error(
                    status: response.statusCode,
                    data: data,
                    unauthorizedSemantics: api.unauthorizedSemantics
                )
            }
            return data
        }

        guard let tokens = try store.loadTokens() else {
            throw NeuAuthError.notAuthenticated
        }
        // Proactively refresh a locally-expired token so the first attempt
        // already carries a good bearer (still funneled through the
        // single-flight task, so this cannot race the reactive path).
        var accessToken = tokens.accessToken
        if tokens.isExpired(now: now()) {
            accessToken = try await refreshTokens().accessToken
        }

        let (data, response) = try await Self.perform(
            http, api.urlRequest(config: config, accessToken: accessToken)
        )
        if response.statusCode != 401 {
            guard (200...299).contains(response.statusCode) else {
                throw ResponseMapper.error(
                    status: response.statusCode,
                    data: data,
                    unauthorizedSemantics: api.unauthorizedSemantics
                )
            }
            return data
        }

        // Reactive 401 → refresh → retry once.
        let freshToken = try await refreshTokens().accessToken
        let (retryData, retryResponse) = try await Self.perform(
            http, api.urlRequest(config: config, accessToken: freshToken)
        )
        if retryResponse.statusCode == 401 {
            throw NeuAuthError.unauthorized
        }
        guard (200...299).contains(retryResponse.statusCode) else {
            throw ResponseMapper.error(
                status: retryResponse.statusCode,
                data: retryData,
                unauthorizedSemantics: api.unauthorizedSemantics
            )
        }
        return retryData
    }

    /// Wrap transport-layer failures as `NeuAuthError.transport`, passing
    /// typed errors through untouched.
    private static func perform(
        _ http: DataHandler, _ request: URLRequest
    ) async throws -> (Data, HTTPURLResponse) {
        do {
            return try await http(request)
        } catch let error as NeuAuthError {
            throw error
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw NeuAuthError.transport(String(describing: error))
        }
    }

    // MARK: - Bootstrap

    /// Classify launch state. Only an explicit server 401/403 on refresh
    /// yields `.expired` (tokens cleared, device_id kept); any transport or
    /// other failure keeps local state and reports `.offline`.
    public func bootstrap() async -> SessionBootstrap {
        guard let tokens = try? store.loadTokens() else {
            return .noSession
        }
        if !tokens.isExpired(now: now()) {
            return .authenticated(tokens)
        }
        do {
            let fresh = try await refreshTokens()
            return .authenticated(fresh)
        } catch let error as NeuAuthError {
            switch error {
            case .unauthorized, .notAuthenticated:
                try? store.clearTokens()
                return .expired
            default:
                return .offline(tokens)
            }
        } catch {
            return .offline(tokens)
        }
    }

    // MARK: - Proactive refresh

    /// Start the proactive scheduler: sleeps until `exp − 120 s`, refreshes
    /// through the single-flight path, and re-arms off the new token.
    /// Idempotent — restarting cancels the previous scheduler.
    public func startProactiveRefresh() {
        proactiveTask?.cancel()
        proactiveTask = Task { [weak self] in
            await self?.proactiveLoop()
        }
    }

    public func stopProactiveRefresh() {
        proactiveTask?.cancel()
        proactiveTask = nil
    }

    private func proactiveLoop() async {
        while !Task.isCancelled {
            guard let tokens = try? store.loadTokens(), tokens.refreshToken != nil else {
                return  // nothing to keep alive
            }
            let wait = JWTClaims(unverifiedJWT: tokens.accessToken)?
                .secondsUntilExpiry(buffer: 120, now: now()) ?? 0
            if wait > 0 {
                guard (try? await clock.sleep(for: .seconds(wait))) != nil else {
                    return  // cancelled
                }
            }
            do {
                try await refreshTokens()
            } catch NeuAuthError.unauthorized, NeuAuthError.notAuthenticated {
                logger.info("Proactive refresh stopped: session is no longer valid")
                return
            } catch is CancellationError {
                return
            } catch {
                // Transient (transport/server) — fall through to the floor
                // sleep below and try again on the next pass.
            }
            if wait <= 0 {
                // Token already expired / exp-less / refresh failed
                // transiently: floor the cadence so this can never hot-loop
                // or retry-storm the server.
                guard (try? await clock.sleep(for: .seconds(60))) != nil else {
                    return
                }
            }
        }
    }
}
