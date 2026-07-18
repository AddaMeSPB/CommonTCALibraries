import Clocks
import Foundation
@testable import NeuAuthKit
import Testing

@Suite("AuthSession")
struct AuthSessionTests {
    // MARK: - Refresh dedup under concurrency

    @Test("N concurrent 401s trigger exactly one refresh call")
    func refreshDedup() async throws {
        let callerCount = 8
        let gate = Gate()
        let stub = StubBox()

        let http = HTTPStub { request in
            let path = request.url?.path ?? ""
            if path.contains("auth/refresh") {
                // Hold the refresh open until every caller has hit its 401 —
                // guarantees all N callers funnel into the in-flight task.
                await gate.wait()
                let newAccess = Fixture.jwt([
                    "sub": "user-1",
                    "exp": Fixture.now.addingTimeInterval(3600).timeIntervalSince1970,
                ])
                return HTTPStub.response(
                    request, status: 200,
                    body: Fixture.grantJSON(accessToken: newAccess, refreshToken: "refresh-2")
                )
            }
            // Authed endpoint: 401 until the refresh has completed, 200 after
            // (retries always run after the refresh task finishes).
            if await stub.refreshCompleted {
                return HTTPStub.response(request, status: 200, body: Data("{}".utf8))
            }
            return HTTPStub.response(request, status: 401)
        }

        let store = InMemoryKeychainStore(
            tokens: Fixture.tokens(accessExpiresAt: Fixture.now.addingTimeInterval(600))
        )
        let session = AuthSession(
            config: Fixture.config,
            store: store,
            http: http.handler,
            now: { Fixture.now }
        )

        try await withThrowingTaskGroup(of: Void.self) { group in
            for _ in 0..<callerCount {
                group.addTask {
                    _ = try await session.send(.deleteAccount())
                }
            }
            // Wait until every caller's first attempt has 401'd…
            while http.requestCount(pathContains: "users/me") < callerCount {
                await Task.yield()
            }
            // …give them all time to enter refreshTokens()…
            await megaYield()
            // …then mark refresh "completed" for retries and open the gate.
            await stub.markRefreshCompleted()
            await gate.open()
            try await group.waitForAll()
        }

        #expect(http.requestCount(pathContains: "auth/refresh") == 1)
        // Every caller: 1 original attempt + 1 retry.
        #expect(http.requestCount(pathContains: "users/me") == callerCount * 2)
        // Rotated refresh token was persisted.
        #expect(try store.loadTokens()?.refreshToken == "refresh-2")
    }

    @Test("A refresh finishing after the session was replaced cannot clobber the new session")
    func refreshCannotClobberNewerSession() async throws {
        let gate = Gate()
        let http = HTTPStub { request in
            await gate.wait()  // hold the refresh in flight
            let staleAccess = Fixture.jwt([
                "exp": Fixture.now.addingTimeInterval(3600).timeIntervalSince1970
            ])
            return HTTPStub.response(
                request, status: 200,
                body: Fixture.grantJSON(accessToken: staleAccess, refreshToken: "stale-rt")
            )
        }
        let store = InMemoryKeychainStore(
            tokens: Fixture.tokens(
                accessExpiresAt: Fixture.now.addingTimeInterval(-10), refreshToken: "anon-rt"
            )
        )
        let session = AuthSession(
            config: Fixture.config, store: store, http: http.handler, now: { Fixture.now }
        )

        let refreshTask = Task { try await session.refreshTokens() }
        while http.requestCount(pathContains: "auth/refresh") < 1 {
            await Task.yield()
        }

        // Upgrade completes mid-refresh: a brand-new registered session lands.
        let upgraded = NeuAuthTokens(
            accessToken: "upgraded-at", refreshToken: "upgraded-rt", idToken: nil,
            expiresAt: Fixture.now.addingTimeInterval(900)
        )
        try await session.setTokens(upgraded)
        await gate.open()

        // The stale refresh is discarded AND the awaiting operation aborts —
        // it must not silently continue under the NEW account's bearer.
        await #expect(throws: NeuAuthError.sessionReplaced) {
            _ = try await refreshTask.value
        }
        #expect(try store.loadTokens() == upgraded)
    }

    @Test("A 401'd request aborts (sessionReplaced) if a new session landed mid-flight")
    func staleRequestAbortsOnSessionReplacement() async throws {
        let gate = Gate()
        let http = HTTPStub { request in
            await gate.wait()
            return HTTPStub.response(request, status: 401)
        }
        let store = InMemoryKeychainStore(
            tokens: Fixture.tokens(accessExpiresAt: Fixture.now.addingTimeInterval(600))
        )
        let session = AuthSession(
            config: Fixture.config, store: store, http: http.handler, now: { Fixture.now }
        )

        let sendTask = Task { try await session.send(.deleteAccount()) }
        while http.requestCount(pathContains: "users/me") < 1 {
            await Task.yield()
        }
        // A different account signs in while the DELETE is in flight.
        let replacement = NeuAuthTokens(
            accessToken: "new-at", refreshToken: "new-rt", idToken: nil,
            expiresAt: Fixture.now.addingTimeInterval(900)
        )
        try await session.setTokens(replacement)
        await gate.open()

        // The stale DELETE must NOT refresh-and-retry under the new account.
        await #expect(throws: NeuAuthError.sessionReplaced) {
            _ = try await sendTask.value
        }
        #expect(http.requestCount(pathContains: "users/me") == 1)  // no retry
        #expect(http.requestCount(pathContains: "auth/refresh") == 0)
        #expect(try store.loadTokens() == replacement)  // untouched
    }

    // MARK: - Retry-once semantics

    @Test("401 after successful refresh throws unauthorized (no retry storm)")
    func retryOnceThenUnauthorized() async throws {
        let http = HTTPStub { request in
            let path = request.url?.path ?? ""
            if path.contains("auth/refresh") {
                let newAccess = Fixture.jwt([
                    "exp": Fixture.now.addingTimeInterval(3600).timeIntervalSince1970
                ])
                return HTTPStub.response(
                    request, status: 200, body: Fixture.grantJSON(accessToken: newAccess)
                )
            }
            return HTTPStub.response(request, status: 401)  // always unauthorized
        }
        let store = InMemoryKeychainStore(
            tokens: Fixture.tokens(accessExpiresAt: Fixture.now.addingTimeInterval(600)),
            deviceID: "device-1"
        )
        let session = AuthSession(
            config: Fixture.config,
            store: store,
            http: http.handler,
            now: { Fixture.now }
        )

        await #expect(throws: NeuAuthError.unauthorized) {
            _ = try await session.send(.deleteAccount())
        }
        #expect(http.requestCount(pathContains: "users/me") == 2)  // attempt + one retry
        #expect(http.requestCount(pathContains: "auth/refresh") == 1)
        // Dead session may not survive locally: a relaunch bootstrap must
        // not resurrect it off the unexpired refreshed copy.
        #expect(try store.loadTokens() == nil)
        #expect(try store.loadDeviceID() == "device-1")
    }

    @Test("Failed refresh surfaces unauthorized without retrying the request")
    func refreshRejectedNoRetry() async throws {
        let http = HTTPStub { request in
            let path = request.url?.path ?? ""
            if path.contains("auth/refresh") {
                return HTTPStub.response(request, status: 401)
            }
            return HTTPStub.response(request, status: 401)
        }
        let session = AuthSession(
            config: Fixture.config,
            store: InMemoryKeychainStore(
                tokens: Fixture.tokens(accessExpiresAt: Fixture.now.addingTimeInterval(600))
            ),
            http: http.handler,
            now: { Fixture.now }
        )

        await #expect(throws: NeuAuthError.unauthorized) {
            _ = try await session.send(.deleteAccount())
        }
        #expect(http.requestCount(pathContains: "users/me") == 1)  // no retry after dead refresh
    }

    @Test("Authed verification 401 maps to invalidOrExpiredCode without refresh/retry")
    func authedInvalidCodeNoRefresh() async throws {
        // upgradeVerify is authed but its 401 means "wrong code" — the
        // transport must NOT refresh-and-resubmit (that burns an OTP attempt
        // and misreports a typo as session expiry).
        let http = HTTPStub { request in
            HTTPStub.response(request, status: 401)
        }
        let session = AuthSession(
            config: Fixture.config,
            store: InMemoryKeychainStore(
                tokens: Fixture.tokens(accessExpiresAt: Fixture.now.addingTimeInterval(600))
            ),
            http: http.handler,
            now: { Fixture.now }
        )

        await #expect(throws: NeuAuthError.invalidOrExpiredCode) {
            _ = try await session.send(
                .upgradeVerify(email: "a@b.c", code: "000000", password: nil, displayName: nil)
            )
        }
        #expect(http.requestCount(pathContains: "auth/refresh") == 0)
        #expect(http.requestCount(pathContains: "upgrade/verify") == 1)  // no resubmission
    }

    @Test("Refresh response omitting refresh_token keeps the previous one")
    func refreshWithoutRotationKeepsToken() async throws {
        let newAccess = Fixture.jwt([
            "exp": Fixture.now.addingTimeInterval(3600).timeIntervalSince1970
        ])
        let http = HTTPStub { request in
            // RFC 6749 §6 allows the server to omit refresh_token.
            HTTPStub.response(
                request, status: 200,
                body: Data(
                    """
                    {"access_token":"\(newAccess)","token_type":"Bearer","expires_in":900}
                    """.utf8
                )
            )
        }
        let store = InMemoryKeychainStore(
            tokens: Fixture.tokens(
                accessExpiresAt: Fixture.now.addingTimeInterval(-10), refreshToken: "keep-me"
            )
        )
        let session = AuthSession(
            config: Fixture.config, store: store, http: http.handler, now: { Fixture.now }
        )

        let refreshed = try await session.refreshTokens()
        #expect(refreshed.refreshToken == "keep-me")
        #expect(try store.loadTokens()?.refreshToken == "keep-me")
        // And the session can refresh again later.
        #expect(try store.loadTokens()?.accessToken == newAccess)
    }

    @Test("Pre-token endpoints bypass bearer and refresh entirely")
    func preTokenBypass() async throws {
        let http = HTTPStub { request in
            HTTPStub.response(request, status: 401)  // "wrong code"
        }
        // Even with EXPIRED stored tokens present, otp/verify must not
        // attach a bearer or attempt a refresh.
        let session = AuthSession(
            config: Fixture.config,
            store: InMemoryKeychainStore(
                tokens: Fixture.tokens(accessExpiresAt: Fixture.now.addingTimeInterval(-600))
            ),
            http: http.handler,
            now: { Fixture.now }
        )

        await #expect(throws: NeuAuthError.invalidOrExpiredCode) {
            _ = try await session.send(.otpVerify(email: "a@b.c", code: "000000"))
        }
        #expect(http.requestCount(pathContains: "auth/refresh") == 0)
        #expect(http.requests.count == 1)
        #expect(http.requests[0].value(forHTTPHeaderField: "Authorization") == nil)
    }

    @Test("Locally-expired token refreshes before the first attempt")
    func proactiveLocalExpiryRefresh() async throws {
        let http = HTTPStub { request in
            let path = request.url?.path ?? ""
            if path.contains("auth/refresh") {
                let newAccess = Fixture.jwt([
                    "exp": Fixture.now.addingTimeInterval(3600).timeIntervalSince1970
                ])
                return HTTPStub.response(
                    request, status: 200, body: Fixture.grantJSON(accessToken: newAccess)
                )
            }
            return HTTPStub.response(request, status: 200)
        }
        let session = AuthSession(
            config: Fixture.config,
            store: InMemoryKeychainStore(
                tokens: Fixture.tokens(accessExpiresAt: Fixture.now.addingTimeInterval(-10))
            ),
            http: http.handler,
            now: { Fixture.now }
        )

        _ = try await session.send(.deleteAccount())
        #expect(http.requestCount(pathContains: "auth/refresh") == 1)
        #expect(http.requestCount(pathContains: "users/me") == 1)
        // The single API attempt already carried the refreshed bearer.
        let apiRequest = http.requests.first { $0.url?.path.contains("users/me") == true }
        let auth = apiRequest?.value(forHTTPHeaderField: "Authorization")
        #expect(auth?.hasPrefix("Bearer ") == true)
        #expect(auth?.contains("eyJ") == true)
    }

    // MARK: - Bootstrap classification

    @Test("Bootstrap: no stored tokens → noSession")
    func bootstrapNoSession() async {
        let http = HTTPStub { request in HTTPStub.response(request, status: 500) }
        let session = AuthSession(
            config: Fixture.config, store: InMemoryKeychainStore(),
            http: http.handler, now: { Fixture.now }
        )
        #expect(await session.bootstrap() == .noSession)
        #expect(http.requests.isEmpty)
    }

    @Test("Bootstrap: valid tokens → authenticated with zero network calls")
    func bootstrapValid() async {
        let tokens = Fixture.tokens(accessExpiresAt: Fixture.now.addingTimeInterval(600))
        let http = HTTPStub { request in HTTPStub.response(request, status: 500) }
        let session = AuthSession(
            config: Fixture.config, store: InMemoryKeychainStore(tokens: tokens),
            http: http.handler, now: { Fixture.now }
        )
        #expect(await session.bootstrap() == .authenticated(tokens))
        #expect(http.requests.isEmpty)
    }

    @Test("Bootstrap: expired + refresh 401 → expired; tokens cleared, device_id kept")
    func bootstrapExpired() async throws {
        let store = InMemoryKeychainStore(
            tokens: Fixture.tokens(accessExpiresAt: Fixture.now.addingTimeInterval(-600)),
            deviceID: "device-keep-me"
        )
        let http = HTTPStub { request in HTTPStub.response(request, status: 401) }
        let session = AuthSession(
            config: Fixture.config, store: store, http: http.handler, now: { Fixture.now }
        )
        #expect(await session.bootstrap() == .expired)
        #expect(try store.loadTokens() == nil)
        #expect(try store.loadDeviceID() == "device-keep-me")
    }

    @Test("Bootstrap: expired + transport failure → offline, tokens kept")
    func bootstrapOffline() async throws {
        let tokens = Fixture.tokens(accessExpiresAt: Fixture.now.addingTimeInterval(-600))
        let store = InMemoryKeychainStore(tokens: tokens)
        let http = HTTPStub { _ in
            throw URLError(.notConnectedToInternet)
        }
        let session = AuthSession(
            config: Fixture.config, store: store, http: http.handler, now: { Fixture.now }
        )
        #expect(await session.bootstrap() == .offline(tokens))
        #expect(try store.loadTokens() == tokens)
    }

    @Test("Bootstrap: expired + server 5xx → offline (outage is not a logout)")
    func bootstrapServerErrorIsOffline() async throws {
        let tokens = Fixture.tokens(accessExpiresAt: Fixture.now.addingTimeInterval(-600))
        let store = InMemoryKeychainStore(tokens: tokens)
        let http = HTTPStub { request in HTTPStub.response(request, status: 503) }
        let session = AuthSession(
            config: Fixture.config, store: store, http: http.handler, now: { Fixture.now }
        )
        #expect(await session.bootstrap() == .offline(tokens))
        #expect(try store.loadTokens() == tokens)
    }

    @Test("Bootstrap: expired + refresh success → authenticated with fresh tokens")
    func bootstrapRefreshed() async throws {
        let newAccess = Fixture.jwt([
            "exp": Fixture.now.addingTimeInterval(3600).timeIntervalSince1970
        ])
        let store = InMemoryKeychainStore(
            tokens: Fixture.tokens(accessExpiresAt: Fixture.now.addingTimeInterval(-600))
        )
        let http = HTTPStub { request in
            HTTPStub.response(
                request, status: 200,
                body: Fixture.grantJSON(accessToken: newAccess, refreshToken: "refresh-2")
            )
        }
        let session = AuthSession(
            config: Fixture.config, store: store, http: http.handler, now: { Fixture.now }
        )
        guard case .authenticated(let fresh) = await session.bootstrap() else {
            Issue.record("expected .authenticated")
            return
        }
        #expect(fresh.accessToken == newAccess)
        #expect(fresh.refreshToken == "refresh-2")
        #expect(try store.loadTokens() == fresh)
    }

    // MARK: - Proactive scheduler

    @Test("Proactive refresh fires at exp − 120 s, driven by the injected clock")
    func proactiveTiming() async throws {
        let clock = TestClock()
        // Access token expires 300 s from now → refresh due after 180 s.
        let store = InMemoryKeychainStore(
            tokens: Fixture.tokens(accessExpiresAt: Fixture.now.addingTimeInterval(300))
        )
        let http = HTTPStub { request in
            let newAccess = Fixture.jwt([
                "exp": Fixture.now.addingTimeInterval(3600).timeIntervalSince1970
            ])
            return HTTPStub.response(
                request, status: 200, body: Fixture.grantJSON(accessToken: newAccess)
            )
        }
        let session = AuthSession(
            config: Fixture.config, store: store, http: http.handler,
            clock: clock, now: { Fixture.now }
        )

        await session.startProactiveRefresh()
        await megaYield()  // let the loop reach its clock.sleep

        await clock.advance(by: .seconds(179))
        await megaYield()
        #expect(http.requestCount(pathContains: "auth/refresh") == 0)

        await clock.advance(by: .seconds(1))
        while http.requestCount(pathContains: "auth/refresh") < 1 {
            await Task.yield()
        }
        #expect(http.requestCount(pathContains: "auth/refresh") == 1)

        // New token (exp now + 3600) re-arms the loop; nothing more fires in
        // the next few minutes.
        await megaYield()
        await clock.advance(by: .seconds(300))
        await megaYield()
        #expect(http.requestCount(pathContains: "auth/refresh") == 1)

        await session.stopProactiveRefresh()
    }

    @Test("Proactive scheduler stops when the session dies")
    func proactiveStopsOnUnauthorized() async throws {
        let clock = TestClock()
        let store = InMemoryKeychainStore(
            tokens: Fixture.tokens(accessExpiresAt: Fixture.now.addingTimeInterval(300))
        )
        let http = HTTPStub { request in HTTPStub.response(request, status: 401) }
        let session = AuthSession(
            config: Fixture.config, store: store, http: http.handler,
            clock: clock, now: { Fixture.now }
        )

        await session.startProactiveRefresh()
        await megaYield()
        await clock.advance(by: .seconds(180))
        while http.requestCount(pathContains: "auth/refresh") < 1 {
            await Task.yield()
        }
        await megaYield()
        // Loop exited: advancing further schedules nothing new.
        await clock.advance(by: .seconds(3600))
        await megaYield()
        #expect(http.requestCount(pathContains: "auth/refresh") == 1)
    }

    @Test("setTokens re-arms the proactive scheduler for the new session")
    func proactiveReArmsOnSetTokens() async throws {
        let clock = TestClock()
        let store = InMemoryKeychainStore()  // no session at start
        let http = HTTPStub { request in
            let newAccess = Fixture.jwt([
                "exp": Fixture.now.addingTimeInterval(3600).timeIntervalSince1970
            ])
            return HTTPStub.response(
                request, status: 200, body: Fixture.grantJSON(accessToken: newAccess)
            )
        }
        let session = AuthSession(
            config: Fixture.config, store: store, http: http.handler,
            clock: clock, now: { Fixture.now }
        )

        // Started with no session: the loop exits immediately…
        await session.startProactiveRefresh()
        await megaYield()

        // …but a later sign-in re-arms it against the new token's expiry.
        try await session.setTokens(
            Fixture.tokens(accessExpiresAt: Fixture.now.addingTimeInterval(300))
        )
        await megaYield()
        await clock.advance(by: .seconds(180))
        while http.requestCount(pathContains: "auth/refresh") < 1 {
            await Task.yield()
        }
        #expect(http.requestCount(pathContains: "auth/refresh") == 1)
        await session.stopProactiveRefresh()
    }

    @Test("Server-rejected refresh clears the dead session's tokens (device_id kept)")
    func rejectedRefreshClearsTokens() async throws {
        let store = InMemoryKeychainStore(
            tokens: Fixture.tokens(accessExpiresAt: Fixture.now.addingTimeInterval(-10)),
            deviceID: "device-1"
        )
        let http = HTTPStub { request in HTTPStub.response(request, status: 401) }
        let session = AuthSession(
            config: Fixture.config, store: store, http: http.handler, now: { Fixture.now }
        )

        await #expect(throws: NeuAuthError.unauthorized) {
            try await session.refreshTokens()
        }
        #expect(try store.loadTokens() == nil)
        #expect(try store.loadDeviceID() == "device-1")
    }

    @Test("Transient failure at the scheduled refresh time backs off, no double-fire")
    func proactiveTransientBackoff() async throws {
        let clock = TestClock()
        let store = InMemoryKeychainStore(
            tokens: Fixture.tokens(accessExpiresAt: Fixture.now.addingTimeInterval(300))
        )
        let http = HTTPStub { request in HTTPStub.response(request, status: 503) }
        let session = AuthSession(
            config: Fixture.config, store: store, http: http.handler,
            clock: clock, now: { Fixture.now }
        )

        await session.startProactiveRefresh()
        await megaYield()
        await clock.advance(by: .seconds(180))
        while http.requestCount(pathContains: "auth/refresh") < 1 {
            await Task.yield()
        }
        await megaYield()
        // Failed transiently — the loop must floor-sleep, not immediately
        // fire a second request.
        #expect(http.requestCount(pathContains: "auth/refresh") == 1)
        await clock.advance(by: .seconds(59))
        await megaYield()
        #expect(http.requestCount(pathContains: "auth/refresh") == 1)
        await session.stopProactiveRefresh()
    }

    @Test("Proactive scheduler stops for a non-JWT access token (no 60 s hammering)")
    func proactiveStopsOnUndecodableToken() async throws {
        let clock = TestClock()
        let store = InMemoryKeychainStore(
            tokens: NeuAuthTokens(
                accessToken: "opaque-not-a-jwt", refreshToken: "rt", idToken: nil,
                expiresAt: Fixture.now.addingTimeInterval(300)
            )
        )
        let http = HTTPStub { request in HTTPStub.response(request, status: 200) }
        let session = AuthSession(
            config: Fixture.config, store: store, http: http.handler,
            clock: clock, now: { Fixture.now }
        )

        await session.startProactiveRefresh()
        await megaYield()
        await clock.advance(by: .seconds(3600))
        await megaYield()
        #expect(http.requests.isEmpty)
    }

    // MARK: - validAccessToken

    @Test("validAccessToken returns stored token when fresh, refreshes when expired")
    func validAccessToken() async throws {
        let freshTokens = Fixture.tokens(accessExpiresAt: Fixture.now.addingTimeInterval(600))
        let http = HTTPStub { request in
            let newAccess = Fixture.jwt([
                "exp": Fixture.now.addingTimeInterval(3600).timeIntervalSince1970
            ])
            return HTTPStub.response(
                request, status: 200, body: Fixture.grantJSON(accessToken: newAccess)
            )
        }
        let store = InMemoryKeychainStore(tokens: freshTokens)
        let session = AuthSession(
            config: Fixture.config, store: store, http: http.handler, now: { Fixture.now }
        )

        #expect(try await session.validAccessToken() == freshTokens.accessToken)
        #expect(http.requests.isEmpty)

        try store.saveTokens(Fixture.tokens(accessExpiresAt: Fixture.now.addingTimeInterval(-5)))
        let refreshed = try await session.validAccessToken()
        #expect(refreshed != freshTokens.accessToken)
        #expect(http.requestCount(pathContains: "auth/refresh") == 1)
    }

    @Test("validAccessToken with no credentials throws notAuthenticated")
    func validAccessTokenNoCredentials() async {
        let http = HTTPStub { request in HTTPStub.response(request, status: 200) }
        let session = AuthSession(
            config: Fixture.config, store: InMemoryKeychainStore(),
            http: http.handler, now: { Fixture.now }
        )
        await #expect(throws: NeuAuthError.notAuthenticated) {
            _ = try await session.validAccessToken()
        }
    }
}

/// Mutable flag shared with the stub closure.
private actor StubBox {
    private(set) var refreshCompleted = false
    func markRefreshCompleted() { refreshCompleted = true }
}
