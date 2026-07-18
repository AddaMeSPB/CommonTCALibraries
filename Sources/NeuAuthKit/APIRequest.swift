import Foundation

/// How a 401 from this endpoint should be interpreted.
enum UnauthorizedSemantics: Sendable {
    /// 401 means the bearer session is invalid → `NeuAuthError.unauthorized`
    /// (the transport reacts by refreshing + retrying once).
    case session
    /// 401 means a wrong/expired verification code →
    /// `NeuAuthError.invalidOrExpiredCode`. Never triggers a refresh.
    case invalidCode
}

/// A NeuAuth API request description: method, path, JSON body, and whether it
/// runs through the authed transport (Bearer + 401-refresh-retry) or the
/// pre-token path.
struct APIRequest: Sendable {
    var method: String
    var path: String
    var body: Data?
    var requiresAuth: Bool
    var unauthorizedSemantics: UnauthorizedSemantics

    init(
        method: String,
        path: String,
        body: Data? = nil,
        requiresAuth: Bool,
        unauthorizedSemantics: UnauthorizedSemantics = .session
    ) {
        self.method = method
        self.path = path
        self.body = body
        self.requiresAuth = requiresAuth
        self.unauthorizedSemantics = unauthorizedSemantics
    }

    /// Build the `URLRequest`. Every request carries `X-Client-ID` so NeuAuth
    /// can resolve the tenant on unauthenticated flows.
    func urlRequest(config: NeuAuthConfig, accessToken: String?) -> URLRequest {
        var request = URLRequest(url: config.issuerBaseURL.appendingPathComponent(path))
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(config.clientID, forHTTPHeaderField: "X-Client-ID")
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = body
        }
        if let accessToken {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }
        return request
    }
}

// MARK: - JSON coding

enum NeuAuthJSON {
    /// Encoder for request bodies. NeuAuth request fields are snake_case and
    /// encoded per-model via explicit `CodingKeys`, so no key strategy here.
    static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    /// Decoder for response bodies. NeuAuth (chrono `DateTime<Utc>`) emits
    /// RFC3339 with fractional seconds; plain `.iso8601` rejects those, so a
    /// custom strategy accepts both forms. Formatters are built inside the
    /// closure because `ISO8601DateFormatter` is not `Sendable` and the
    /// `.custom` callback is `@Sendable` under Swift 6.
    static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let fractional = ISO8601DateFormatter()
            fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let plain = ISO8601DateFormatter()
            plain.formatOptions = [.withInternetDateTime]
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            if let date = fractional.date(from: string) { return date }
            if let date = plain.date(from: string) { return date }
            throw DecodingError.dataCorruptedError(
                in: container, debugDescription: "invalid RFC3339 date: \(string)"
            )
        }
        return decoder
    }
}

// MARK: - Endpoint catalogue

extension APIRequest {
    private static func jsonBody(_ object: [String: Any?]) -> Data {
        let compacted = object.compactMapValues { $0 }
        // Keys/values here are always JSON-safe (strings, UUID strings,
        // nested string dictionaries) — a serialization failure would be a
        // programmer error, so fall back to an empty object.
        return (try? JSONSerialization.data(withJSONObject: compacted)) ?? Data("{}".utf8)
    }

    // MARK: Email OTP

    static func otpSend(email: String, purpose: OTPPurpose) -> APIRequest {
        APIRequest(
            method: "POST",
            path: "api/v1/auth/otp/send",
            body: jsonBody(["email": email, "purpose": purpose.rawValue]),
            requiresAuth: false
        )
    }

    static func otpVerify(email: String, code: String) -> APIRequest {
        APIRequest(
            method: "POST",
            path: "api/v1/auth/otp/verify",
            body: jsonBody(["email": email, "code": code]),
            requiresAuth: false,
            unauthorizedSemantics: .invalidCode
        )
    }

    // MARK: Tokens / session

    static func refresh(refreshToken: String) -> APIRequest {
        APIRequest(
            method: "POST",
            path: "api/v1/auth/refresh",
            body: jsonBody(["refresh_token": refreshToken]),
            requiresAuth: false
        )
    }

    static func logout(refreshToken: String) -> APIRequest {
        APIRequest(
            method: "POST",
            path: "api/v1/auth/logout",
            body: jsonBody(["refresh_token": refreshToken]),
            requiresAuth: false
        )
    }

    static func deleteAccount() -> APIRequest {
        APIRequest(method: "DELETE", path: "api/v1/users/me", requiresAuth: true)
    }

    // MARK: Anonymous

    static func anonymousCreate(
        deviceID: String, platform: String, appVersion: String?
    ) -> APIRequest {
        APIRequest(
            method: "POST",
            path: "api/v1/auth/anonymous",
            body: jsonBody([
                "device_id": deviceID,
                "platform": platform,
                "app_version": appVersion,
            ]),
            requiresAuth: false
        )
    }

    static func upgradeStart(email: String) -> APIRequest {
        APIRequest(
            method: "POST",
            path: "api/v1/auth/anonymous/upgrade",
            body: jsonBody(["method": "email_otp", "email": email]),
            requiresAuth: true
        )
    }

    static func upgradeVerify(
        email: String, code: String, password: String?, displayName: String?
    ) -> APIRequest {
        APIRequest(
            method: "POST",
            path: "api/v1/auth/anonymous/upgrade/verify",
            body: jsonBody([
                "method": "email_otp",
                "email": email,
                "code": code,
                "password": password,
                "display_name": displayName,
            ]),
            requiresAuth: true,
            unauthorizedSemantics: .invalidCode
        )
    }

    static func merge(targetUserID: UUID, code: String) -> APIRequest {
        APIRequest(
            method: "POST",
            path: "api/v1/auth/anonymous/merge",
            body: jsonBody([
                "target_user_id": targetUserID.uuidString.lowercased(),
                "verification": ["method": "email_otp", "code": code],
            ]),
            requiresAuth: true,
            unauthorizedSemantics: .invalidCode
        )
    }

    // MARK: WebAuthn

    static func webauthnRegisterStart(label: String?) -> APIRequest {
        APIRequest(
            method: "POST",
            path: "api/v1/webauthn/register/start",
            body: jsonBody(["label": label]),
            requiresAuth: true
        )
    }

    static func webauthnRegisterFinish(
        challengeKey: String, credential: JSONValue, label: String?
    ) -> APIRequest {
        struct Body: Encodable {
            let challengeKey: String
            let credential: JSONValue
            let label: String?

            enum CodingKeys: String, CodingKey {
                case credential, label
                case challengeKey = "challenge_key"
            }
        }
        let body = (try? NeuAuthJSON.encoder().encode(
            Body(challengeKey: challengeKey, credential: credential, label: label)
        )) ?? Data("{}".utf8)
        return APIRequest(
            method: "POST",
            path: "api/v1/webauthn/register/finish",
            body: body,
            requiresAuth: true
        )
    }

    static func webauthnAuthenticateStart(userID: UUID?) -> APIRequest {
        APIRequest(
            method: "POST",
            path: "api/v1/webauthn/authenticate/start",
            body: jsonBody(["user_id": userID.map { $0.uuidString.lowercased() }]),
            requiresAuth: false
        )
    }

    static func webauthnAuthenticateFinish(
        challengeKey: String, credential: JSONValue
    ) -> APIRequest {
        struct Body: Encodable {
            let challengeKey: String
            let credential: JSONValue

            enum CodingKeys: String, CodingKey {
                case credential
                case challengeKey = "challenge_key"
            }
        }
        let body = (try? NeuAuthJSON.encoder().encode(
            Body(challengeKey: challengeKey, credential: credential)
        )) ?? Data("{}".utf8)
        return APIRequest(
            method: "POST",
            path: "api/v1/webauthn/authenticate/finish",
            body: body,
            requiresAuth: false,
            unauthorizedSemantics: .invalidCode
        )
    }
}

// MARK: - Response error mapping

enum ResponseMapper {
    /// Map a non-2xx response to a typed `NeuAuthError` using the NeuAuth
    /// flat envelope `{ "error": code, "message": text }` where available.
    static func error(
        status: Int,
        data: Data,
        unauthorizedSemantics: UnauthorizedSemantics
    ) -> NeuAuthError {
        let envelope = try? JSONDecoder().decode(NeuAuthErrorEnvelope.self, from: data)
        switch status {
        case 401:
            switch unauthorizedSemantics {
            case .session: return .unauthorized
            case .invalidCode: return .invalidOrExpiredCode
            }
        case 429:
            return .rateLimited(retryAfterSeconds: envelope?.retryAfter)
        case 400, 422:
            return .badRequest(code: envelope?.error, message: envelope?.message)
        case 403:
            return .forbidden(code: envelope?.error, message: envelope?.message)
        case 404:
            return .notFound
        case 409:
            return .conflict(message: envelope?.message)
        default:
            let message = envelope?.message ?? String(data: data, encoding: .utf8)
            return .server(status: status, message: message)
        }
    }
}
