import Foundation
@testable import NeuAuthKit
import Testing

@Suite("Model decoding + live facade mapping")
struct ModelsAndFacadeTests {
    // MARK: - Upgrade steering

    @Test("upgrade email_exists decodes to typed steering result")
    func upgradeEmailExists() throws {
        let existing = UUID()
        let json = Data(
            """
            {"status":"email_exists","message":"This email already belongs to a registered user.","existing_user_id":"\(existing.uuidString)"}
            """.utf8
        )
        let response = try NeuAuthJSON.decoder().decode(UpgradeStartResponse.self, from: json)
        #expect(try response.toUpgradeStart() == .emailExists(existingUserID: existing))
    }

    @Test("upgrade otp_sent decodes with email + expiry")
    func upgradeOtpSent() throws {
        let json = Data(#"{"status":"otp_sent","email":"a@b.c","expires_in":600}"#.utf8)
        let response = try NeuAuthJSON.decoder().decode(UpgradeStartResponse.self, from: json)
        #expect(try response.toUpgradeStart() == .otpSent(email: "a@b.c", expiresIn: 600))
    }

    @Test("unknown upgrade status throws a decoding error")
    func upgradeUnknownStatus() throws {
        let json = Data(#"{"status":"mystery"}"#.utf8)
        let response = try NeuAuthJSON.decoder().decode(UpgradeStartResponse.self, from: json)
        #expect(throws: NeuAuthError.self) {
            _ = try response.toUpgradeStart()
        }
    }

    // MARK: - Wire decoding

    @Test("token grant maps expires_in to an absolute expiresAt")
    func tokenGrant() throws {
        let json = Fixture.grantJSON(accessToken: "at", refreshToken: "rt", expiresIn: 900)
        let grant = try NeuAuthJSON.decoder().decode(TokenGrantResponse.self, from: json)
        let tokens = grant.toTokens(now: Fixture.now)
        #expect(tokens.accessToken == "at")
        #expect(tokens.refreshToken == "rt")
        #expect(tokens.expiresAt == Fixture.now.addingTimeInterval(900))
    }

    @Test("anonymous create response decodes user + tokens")
    func anonymousCreate() throws {
        let userID = UUID()
        let json = Data(
            """
            {"user":{"id":"\(userID.uuidString)","is_anonymous":true,"created_at":"2026-07-18T09:00:00.123456Z"},
             "tokens":{"access_token":"anon-at","refresh_token":"anon-rt","token_type":"Bearer","expires_in":900}}
            """.utf8
        )
        let response = try NeuAuthJSON.decoder().decode(AnonymousCreateResponse.self, from: json)
        let session = response.toSession(now: Fixture.now)
        #expect(session.userID == userID)
        #expect(session.isAnonymous == true)
        #expect(session.tokens.accessToken == "anon-at")
        #expect(session.tokens.refreshToken == "anon-rt")
        #expect(session.tokens.expiresAt == Fixture.now.addingTimeInterval(900))
    }

    @Test("upgrade complete + merge responses decode migration summaries")
    func upgradeCompleteAndMerge() throws {
        let userID = UUID()
        let upgradeJSON = Data(
            """
            {"user":{"id":"\(userID.uuidString)","is_anonymous":false,"email":"a@b.c","display_name":"Alif","upgraded_at":"2026-07-18T09:00:00Z"},
             "tokens":{"access_token":"at2","refresh_token":"rt2","token_type":"Bearer","expires_in":900},
             "data_migrated":{"total_items":12,"by_type":{"favorites":12}}}
            """.utf8
        )
        let upgrade = try NeuAuthJSON.decoder()
            .decode(UpgradeCompleteResponse.self, from: upgradeJSON)
            .toUpgradeComplete(now: Fixture.now)
        #expect(upgrade.userID == userID)
        #expect(upgrade.email == "a@b.c")
        #expect(upgrade.displayName == "Alif")
        #expect(upgrade.migratedItemCount == 12)

        let target = UUID()
        let mergeJSON = Data(
            """
            {"merged_into":"\(target.uuidString)","anonymous_user_deleted":true,
             "data_migrated":{"total_items":7,"by_type":{}},
             "tokens":{"access_token":"at3","refresh_token":"rt3","token_type":"Bearer","expires_in":900}}
            """.utf8
        )
        let merge = try NeuAuthJSON.decoder()
            .decode(MergeResponse.self, from: mergeJSON)
            .toMergeResult(now: Fixture.now)
        #expect(merge.mergedInto == target)
        #expect(merge.anonymousUserDeleted == true)
        #expect(merge.migratedItemCount == 7)
        #expect(merge.tokens.accessToken == "at3")
    }

    @Test("webauthn challenge passes webauthn-rs options through as JSON")
    func webauthnChallengePassthrough() throws {
        let json = Data(
            """
            {"challenge_key":"ck-1","options":{"publicKey":{"challenge":"AQIDBA","user":{"id":"dXNlcg"},"timeout":60000}}}
            """.utf8
        )
        let response = try NeuAuthJSON.decoder().decode(WebAuthnChallengeResponse.self, from: json)
        #expect(response.challengeKey == "ck-1")
        let publicKey = response.options["publicKey"]
        #expect(publicKey?["timeout"]?.numberValue == 60000)
        #expect(publicKey?["challenge"]?.stringValue == "AQIDBA")
        // base64url decode round-trip for binary fields
        #expect(publicKey?["challenge"]?.base64URLDecodedData == Data([1, 2, 3, 4]))
        #expect(publicKey?["user"]?["id"]?.base64URLDecodedData == Data("user".utf8))
    }

    // MARK: - Live facade over scripted HTTP

    private func makeLive(
        store: InMemoryKeychainStore,
        respond: @escaping @Sendable (URLRequest) async throws -> (Data, HTTPURLResponse)
    ) -> (NeuAuthClient, HTTPStub) {
        let stub = HTTPStub(respond: respond)
        let session = AuthSession(
            config: Fixture.config, store: store, http: stub.handler, now: { Fixture.now }
        )
        return (NeuAuthClient.live(session: session), stub)
    }

    @Test("verifyEmailCode persists tokens and returns the user")
    func verifyEmailCodePersists() async throws {
        let store = InMemoryKeychainStore()
        let userID = UUID()
        let tenantID = UUID()
        let (client, _) = makeLive(store: store) { request in
            let body = Data(
                """
                {"access_token":"at-new","token_type":"Bearer","expires_in":900,"refresh_token":"rt-new",
                 "user":{"id":"\(userID.uuidString)","email":"a@b.c","email_verified":true,"display_name":null,
                         "avatar_url":null,"phone":null,"roles":["user"],"tenant_id":"\(tenantID.uuidString)"}}
                """.utf8
            )
            return HTTPStub.response(request, status: 200, body: body)
        }

        let result = try await client.verifyEmailCode("a@b.c", "123456")
        #expect(result.user?.id == userID)
        #expect(result.user?.email == "a@b.c")
        #expect(result.tokens.accessToken == "at-new")
        #expect(try store.loadTokens() == result.tokens)
    }

    @Test("verifyEmailCode wrong code → invalidOrExpiredCode, no refresh attempted")
    func verifyEmailCodeWrongCode() async throws {
        let store = InMemoryKeychainStore(
            tokens: Fixture.tokens(accessExpiresAt: Fixture.now.addingTimeInterval(-600))
        )
        let (client, stub) = makeLive(store: store) { request in
            HTTPStub.response(
                request, status: 401,
                body: Data(#"{"error":"unauthorized","message":"Invalid verification code"}"#.utf8)
            )
        }

        await #expect(throws: NeuAuthError.invalidOrExpiredCode) {
            _ = try await client.verifyEmailCode("a@b.c", "999999")
        }
        #expect(stub.requestCount(pathContains: "auth/refresh") == 0)
    }

    @Test("signInAnonymously creates + persists device_id and reuses it")
    func signInAnonymouslyDeviceID() async throws {
        let store = InMemoryKeychainStore()
        let userID = UUID()
        let (client, stub) = makeLive(store: store) { request in
            let body = Data(
                """
                {"user":{"id":"\(userID.uuidString)","is_anonymous":true,"created_at":"2026-07-18T09:00:00Z"},
                 "tokens":{"access_token":"anon-at","refresh_token":"anon-rt","token_type":"Bearer","expires_in":900}}
                """.utf8
            )
            return HTTPStub.response(request, status: 201, body: body)
        }

        #expect(try await client.anonymousDeviceID() == nil)
        let first = try await client.signInAnonymously("ios", "1.0.0")
        #expect(first.userID == userID)
        #expect(first.isAnonymous)

        let deviceID = try await client.anonymousDeviceID()
        #expect(deviceID != nil)
        #expect(try store.loadTokens()?.accessToken == "anon-at")

        // Second sign-in (e.g. after token expiry) reuses the SAME device id
        // → server reconnects the same anonymous account.
        _ = try await client.signInAnonymously("ios", "1.0.0")
        #expect(try await client.anonymousDeviceID() == deviceID)
        let bodies = stub.requests.map(bodyJSON)
        #expect(bodies.count == 2)
        #expect(bodies[0]["device_id"] as? String == deviceID)
        #expect(bodies[1]["device_id"] as? String == deviceID)
    }

    @Test("startUpgrade maps email_exists through the live client")
    func startUpgradeEmailExists() async throws {
        let existing = UUID()
        let store = InMemoryKeychainStore(
            tokens: Fixture.tokens(accessExpiresAt: Fixture.now.addingTimeInterval(600))
        )
        let (client, _) = makeLive(store: store) { request in
            HTTPStub.response(
                request, status: 200,
                body: Data(
                    """
                    {"status":"email_exists","message":"…","existing_user_id":"\(existing.uuidString)"}
                    """.utf8
                )
            )
        }

        let result = try await client.startUpgrade("taken@example.com")
        #expect(result == .emailExists(existingUserID: existing))
    }

    @Test("logout clears tokens but keeps device_id; deleteAccount clears both")
    func logoutVsDeleteAccount() async throws {
        let store = InMemoryKeychainStore(
            tokens: Fixture.tokens(accessExpiresAt: Fixture.now.addingTimeInterval(600)),
            deviceID: "device-1"
        )
        let (client, _) = makeLive(store: store) { request in
            HTTPStub.response(request, status: 200)
        }

        try await client.logout()
        #expect(try store.loadTokens() == nil)
        #expect(try store.loadDeviceID() == "device-1")

        // Re-arm and delete.
        try store.saveTokens(Fixture.tokens(accessExpiresAt: Fixture.now.addingTimeInterval(600)))
        try await client.deleteAccount()
        #expect(try store.loadTokens() == nil)
        #expect(try store.loadDeviceID() == nil)
    }

    @Test("deleteAccount keeps local state on transport failure, wipes on dead-session 401")
    func deleteAccountFailureModes() async throws {
        // Offline: the account still exists server-side — keep everything.
        let offlineStore = InMemoryKeychainStore(
            tokens: Fixture.tokens(accessExpiresAt: Fixture.now.addingTimeInterval(600)),
            deviceID: "device-1"
        )
        let (offlineClient, _) = makeLive(store: offlineStore) { _ in
            throw URLError(.notConnectedToInternet)
        }
        await #expect(throws: NeuAuthError.self) {
            try await offlineClient.deleteAccount()
        }
        #expect(try offlineStore.loadTokens() != nil)
        #expect(try offlineStore.loadDeviceID() == "device-1")

        // Session already dead server-side (401 even after refresh): the
        // account is unreachable/gone — wipe local state.
        let deadStore = InMemoryKeychainStore(
            tokens: Fixture.tokens(accessExpiresAt: Fixture.now.addingTimeInterval(600)),
            deviceID: "device-2"
        )
        let (deadClient, _) = makeLive(store: deadStore) { request in
            HTTPStub.response(request, status: 401)
        }
        try await deadClient.deleteAccount()
        #expect(try deadStore.loadTokens() == nil)
        #expect(try deadStore.loadDeviceID() == nil)
    }

    @Test("logout still clears local tokens when revocation fails")
    func logoutOfflineStillClears() async throws {
        let store = InMemoryKeychainStore(
            tokens: Fixture.tokens(accessExpiresAt: Fixture.now.addingTimeInterval(600)),
            deviceID: "device-1"
        )
        let (client, _) = makeLive(store: store) { _ in
            throw URLError(.notConnectedToInternet)
        }
        try await client.logout()
        #expect(try store.loadTokens() == nil)
        #expect(try store.loadDeviceID() == "device-1")
    }
}
