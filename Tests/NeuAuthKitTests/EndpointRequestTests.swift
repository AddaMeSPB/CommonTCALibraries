import Foundation
@testable import NeuAuthKit
import Testing

@Suite("Endpoint request construction")
struct EndpointRequestTests {
    private let config = Fixture.config

    @Test("Every request carries X-Client-ID and Accept headers")
    func commonHeaders() {
        let requests: [APIRequest] = [
            .otpSend(email: "a@b.c", purpose: .login),
            .otpVerify(email: "a@b.c", code: "123456"),
            .refresh(refreshToken: "rt"),
            .logout(refreshToken: "rt"),
            .deleteAccount(),
            .anonymousCreate(deviceID: "dev-1", platform: "ios", appVersion: "1.0"),
            .upgradeStart(email: "a@b.c"),
            .upgradeVerify(email: "a@b.c", code: "123456", password: nil, displayName: nil),
            .merge(targetUserID: UUID(), code: "123456"),
            .webauthnRegisterStart(label: nil),
            .webauthnRegisterFinish(challengeKey: "ck", credential: .object([:]), label: nil),
            .webauthnAuthenticateStart(userID: nil),
            .webauthnAuthenticateFinish(challengeKey: "ck", credential: .object([:])),
        ]
        for request in requests {
            let url = request.urlRequest(config: config, accessToken: nil)
            #expect(url.value(forHTTPHeaderField: "X-Client-ID") == "test-client-id")
            #expect(url.value(forHTTPHeaderField: "Accept") == "application/json")
        }
    }

    @Test("OTP send: URL, method, body, purpose")
    func otpSend() {
        let api = APIRequest.otpSend(email: "user@example.com", purpose: .login)
        let request = api.urlRequest(config: config, accessToken: nil)
        #expect(request.url?.absoluteString == "https://neuauth.example.app/api/v1/auth/otp/send")
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
        #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
        let body = bodyJSON(request)
        #expect(body["email"] as? String == "user@example.com")
        #expect(body["purpose"] as? String == "login")
        #expect(api.requiresAuth == false)
    }

    @Test("OTP send for merge uses anonymous_upgrade purpose")
    func otpSendMergePurpose() {
        let api = APIRequest.otpSend(email: "user@example.com", purpose: .anonymousUpgrade)
        let body = bodyJSON(api.urlRequest(config: config, accessToken: nil))
        #expect(body["purpose"] as? String == "anonymous_upgrade")
    }

    @Test("OTP verify: 401 means invalid code, not session death")
    func otpVerify() {
        let api = APIRequest.otpVerify(email: "user@example.com", code: "482913")
        let request = api.urlRequest(config: config, accessToken: nil)
        #expect(request.url?.path == "/api/v1/auth/otp/verify")
        let body = bodyJSON(request)
        #expect(body["email"] as? String == "user@example.com")
        #expect(body["code"] as? String == "482913")
        #expect(api.requiresAuth == false)
        guard case .invalidCode = api.unauthorizedSemantics else {
            Issue.record("otpVerify must map 401 → invalidOrExpiredCode")
            return
        }
    }

    @Test("Refresh: pre-token, snake_case body")
    func refresh() {
        let api = APIRequest.refresh(refreshToken: "the-refresh-token")
        let request = api.urlRequest(config: config, accessToken: nil)
        #expect(request.url?.path == "/api/v1/auth/refresh")
        #expect(request.httpMethod == "POST")
        #expect(bodyJSON(request)["refresh_token"] as? String == "the-refresh-token")
        #expect(api.requiresAuth == false)
    }

    @Test("Logout posts the refresh token")
    func logout() {
        let api = APIRequest.logout(refreshToken: "rt-9")
        let request = api.urlRequest(config: config, accessToken: nil)
        #expect(request.url?.path == "/api/v1/auth/logout")
        #expect(bodyJSON(request)["refresh_token"] as? String == "rt-9")
    }

    @Test("Delete account: DELETE /users/me, authed")
    func deleteAccount() {
        let api = APIRequest.deleteAccount()
        let request = api.urlRequest(config: config, accessToken: "at-1")
        #expect(request.url?.path == "/api/v1/users/me")
        #expect(request.httpMethod == "DELETE")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer at-1")
        #expect(api.requiresAuth == true)
    }

    @Test("Anonymous create: device_id + platform + app_version")
    func anonymousCreate() {
        let api = APIRequest.anonymousCreate(
            deviceID: "device-uuid-1", platform: "ios", appVersion: "2.1.0"
        )
        let request = api.urlRequest(config: config, accessToken: nil)
        #expect(request.url?.path == "/api/v1/auth/anonymous")
        #expect(request.httpMethod == "POST")
        let body = bodyJSON(request)
        #expect(body["device_id"] as? String == "device-uuid-1")
        #expect(body["platform"] as? String == "ios")
        #expect(body["app_version"] as? String == "2.1.0")
        #expect(api.requiresAuth == false)
    }

    @Test("Anonymous create omits app_version when nil")
    func anonymousCreateNilVersion() {
        let api = APIRequest.anonymousCreate(deviceID: "d", platform: "ios", appVersion: nil)
        let body = bodyJSON(api.urlRequest(config: config, accessToken: nil))
        #expect(body["app_version"] == nil)
    }

    @Test("Upgrade start: authed, email_otp method")
    func upgradeStart() {
        let api = APIRequest.upgradeStart(email: "user@example.com")
        let request = api.urlRequest(config: config, accessToken: "anon-token")
        #expect(request.url?.path == "/api/v1/auth/anonymous/upgrade")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer anon-token")
        let body = bodyJSON(request)
        #expect(body["method"] as? String == "email_otp")
        #expect(body["email"] as? String == "user@example.com")
        #expect(api.requiresAuth == true)
    }

    @Test("Upgrade verify: full body, invalid-code 401 semantics")
    func upgradeVerify() {
        let api = APIRequest.upgradeVerify(
            email: "user@example.com", code: "123456", password: "hunter2xx", displayName: "Alif"
        )
        let request = api.urlRequest(config: config, accessToken: "t")
        #expect(request.url?.path == "/api/v1/auth/anonymous/upgrade/verify")
        let body = bodyJSON(request)
        #expect(body["method"] as? String == "email_otp")
        #expect(body["code"] as? String == "123456")
        #expect(body["password"] as? String == "hunter2xx")
        #expect(body["display_name"] as? String == "Alif")
        guard case .invalidCode = api.unauthorizedSemantics else {
            Issue.record("upgradeVerify must map 401 → invalidOrExpiredCode")
            return
        }
    }

    @Test("Merge: nested verification object")
    func merge() {
        let target = UUID()
        let api = APIRequest.merge(targetUserID: target, code: "654321")
        let request = api.urlRequest(config: config, accessToken: "t")
        #expect(request.url?.path == "/api/v1/auth/anonymous/merge")
        let body = bodyJSON(request)
        #expect(body["target_user_id"] as? String == target.uuidString.lowercased())
        let verification = body["verification"] as? [String: Any]
        #expect(verification?["method"] as? String == "email_otp")
        #expect(verification?["code"] as? String == "654321")
        #expect(api.requiresAuth == true)
    }

    @Test("WebAuthn register start/finish: authed, challenge_key + credential passthrough")
    func webauthnRegister() {
        let start = APIRequest.webauthnRegisterStart(label: "iPhone")
        let startRequest = start.urlRequest(config: config, accessToken: "t")
        #expect(startRequest.url?.path == "/api/v1/webauthn/register/start")
        #expect(bodyJSON(startRequest)["label"] as? String == "iPhone")
        #expect(start.requiresAuth == true)

        let credential = JSONValue.object([
            "id": .string("Y3JlZC1pZA"),
            "response": .object(["clientDataJSON": .string("e30")]),
        ])
        let finish = APIRequest.webauthnRegisterFinish(
            challengeKey: "ck-1", credential: credential, label: "iPhone"
        )
        let finishRequest = finish.urlRequest(config: config, accessToken: "t")
        #expect(finishRequest.url?.path == "/api/v1/webauthn/register/finish")
        let body = bodyJSON(finishRequest)
        #expect(body["challenge_key"] as? String == "ck-1")
        #expect(body["label"] as? String == "iPhone")
        let cred = body["credential"] as? [String: Any]
        #expect(cred?["id"] as? String == "Y3JlZC1pZA")
        #expect(finish.requiresAuth == true)
    }

    @Test("WebAuthn authenticate: pre-token, invalid-code 401 on finish")
    func webauthnAuthenticate() {
        let userID = UUID()
        let start = APIRequest.webauthnAuthenticateStart(userID: userID)
        let startRequest = start.urlRequest(config: config, accessToken: nil)
        #expect(startRequest.url?.path == "/api/v1/webauthn/authenticate/start")
        #expect(bodyJSON(startRequest)["user_id"] as? String == userID.uuidString.lowercased())
        #expect(start.requiresAuth == false)

        let finish = APIRequest.webauthnAuthenticateFinish(
            challengeKey: "ck-2", credential: .object([:])
        )
        #expect(finish.requiresAuth == false)
        guard case .invalidCode = finish.unauthorizedSemantics else {
            Issue.record("authenticate/finish 401 must map to invalidOrExpiredCode")
            return
        }
    }

    @Test("Error mapper: envelope, 429, 401 semantics")
    func errorMapping() {
        let envelope = Data(#"{"error":"bad_request","message":"nope"}"#.utf8)
        #expect(
            ResponseMapper.error(status: 400, data: envelope, unauthorizedSemantics: .session)
                == .badRequest(code: "bad_request", message: "nope")
        )
        #expect(
            ResponseMapper.error(status: 401, data: Data(), unauthorizedSemantics: .session)
                == .unauthorized
        )
        #expect(
            ResponseMapper.error(status: 401, data: Data(), unauthorizedSemantics: .invalidCode)
                == .invalidOrExpiredCode
        )
        let rate = Data(#"{"error":"rate_limited","message":"slow down","retry_after":30}"#.utf8)
        #expect(
            ResponseMapper.error(status: 429, data: rate, unauthorizedSemantics: .session)
                == .rateLimited(retryAfterSeconds: 30)
        )
        #expect(
            ResponseMapper.error(status: 404, data: Data(), unauthorizedSemantics: .session)
                == .notFound
        )
        #expect(
            ResponseMapper.error(status: 500, data: envelope, unauthorizedSemantics: .session)
                == .server(status: 500, message: "nope")
        )
    }
}
