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
        #expect(http.requestCount(pathContains: "users/me") == 2)  // attempt + one retry
        #expect(http.requestCount(pathContains: "auth/refresh") == 1)
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
