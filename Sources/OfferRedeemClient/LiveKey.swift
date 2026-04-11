import Dependencies
import Foundation
import OSLog
import Security
#if canImport(UIKit)
import UIKit
#endif

extension OfferRedeemClient: DependencyKey {
    private static let jsonDecoder = JSONDecoder()
    private static let jsonEncoder = JSONEncoder()

    /// Decode a JSON response, throwing a user-friendly error if the server returned
    /// a non-JSON body (e.g. Caddy "Access denied" plain text on 403).
    private static func decodeOrThrow<T: Decodable>(
        _ type: T.Type,
        from data: Data,
        httpResponse: HTTPURLResponse,
        log: Logger
    ) throws -> T {
        if httpResponse.statusCode >= 400 {
            log.error("HTTP \(httpResponse.statusCode) from \(httpResponse.url?.path ?? "unknown")")
            // Try to extract error message from JSON body
            if let errorBody = try? jsonDecoder.decode([String: String].self, from: data),
               let errorMsg = errorBody["error"] ?? errorBody["message"] {
                throw OfferRedeemError.serverError(errorMsg)
            }
            let body = String(data: data, encoding: .utf8) ?? "Unknown error"
            log.error("Non-JSON error body: \(body)")
            if httpResponse.statusCode == 403 {
                throw OfferRedeemError.serverError(
                    "The server is not accepting requests right now. Please try again later."
                )
            }
            throw OfferRedeemError.serverError(
                "Server error (\(httpResponse.statusCode)): \(body)"
            )
        }
        do {
            return try jsonDecoder.decode(type, from: data)
        } catch {
            log.error("JSON decode failed: \(error.localizedDescription)")
            throw OfferRedeemError.networkError(
                "Unexpected response from server. Please try again later."
            )
        }
    }

    public static let liveValue = OfferRedeemClient(
        preclaim: { slug, email, consent in
            @Dependency(\.offerRedeemConfig) var config
            let log = Logger(subsystem: config.loggerSubsystem, category: "Coupon")
            log.info("Preclaim: slug=\(slug) email=\(maskedEmail(email)) consent=\(consent)")
            guard let url = URL(string: "\(config.baseURL)/api/offers/public/campaigns/\(slug)/preclaim") else {
                throw OfferRedeemError.networkError("Invalid URL for campaign \(slug)")
            }
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let body: [String: Any] = ["email": email, "marketing_consent": consent]
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw OfferRedeemError.networkError("Invalid response")
            }
            let decoded = try decodeOrThrow(OfferPreclaimResponse.self, from: data, httpResponse: httpResponse, log: log)
            log.info("Preclaim success: status=\(decoded.status)")
            return decoded
        },
        verify: { claimId, code, claimToken in
            @Dependency(\.offerRedeemConfig) var config
            let log = Logger(subsystem: config.loggerSubsystem, category: "Coupon")
            log.info("Verify: claimId=\(claimId) code=\(code.prefix(2))****")
            let safeClaimId = claimId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? claimId
            guard let url = URL(string: "\(config.baseURL)/api/offers/public/claims/\(safeClaimId)/verify") else {
                throw OfferRedeemError.networkError("Invalid URL for claim \(claimId)")
            }
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try jsonEncoder.encode(["code": code, "claim_token": claimToken])
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw OfferRedeemError.networkError("Invalid response")
            }
            let decoded = try decodeOrThrow(OfferVerifyResponse.self, from: data, httpResponse: httpResponse, log: log)
            log.info("Verify success: status=\(decoded.status ?? "nil") next_step=\(decoded.next_step ?? "nil")")
            return decoded
        },
        appClaim: { slug, claimToken in
            @Dependency(\.offerRedeemConfig) var config
            let log = Logger(subsystem: config.loggerSubsystem, category: "Coupon")
            log.info("AppClaim: slug=\(slug)")
            guard let url = URL(string: "\(config.baseURL)/api/offers/app/campaigns/\(slug)/claim") else {
                throw OfferRedeemError.networkError("Invalid URL for campaign \(slug)")
            }
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try jsonEncoder.encode([
                "claim_token": claimToken,
                "install_token": InstallTokenManager.installToken(service: config.keychainService),
            ])
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw OfferRedeemError.networkError("Invalid response")
            }
            let decoded = try decodeOrThrow(OfferClaimResponse.self, from: data, httpResponse: httpResponse, log: log)
            log.info("AppClaim success: status=\(decoded.status ?? "nil") has_url=\(decoded.redemption_url != nil)")
            return decoded
        },
        registerDevice: {
            @Dependency(\.offerRedeemConfig) var config
            let log = Logger(subsystem: config.loggerSubsystem, category: "Coupon")
            log.info("RegisterDevice: starting")
            guard let url = URL(string: "\(config.baseURL)/api/offers/app/register-device") else {
                throw OfferRedeemError.networkError("Invalid URL for device registration")
            }
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            #if canImport(UIKit)
            let deviceInfo = await MainActor.run {
                "\(UIDevice.current.model) iOS \(UIDevice.current.systemVersion)"
            }
            #else
            let deviceInfo = "macOS \(ProcessInfo.processInfo.operatingSystemVersionString)"
            #endif
            request.httpBody = try jsonEncoder.encode([
                "app_slug": config.appSlug,
                "install_token": InstallTokenManager.installToken(service: config.keychainService),
                "device_info": deviceInfo,
            ])
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode < 400
            else {
                let code = (response as? HTTPURLResponse)?.statusCode ?? -1
                log.error("RegisterDevice failed: HTTP \(code)")
                throw OfferRedeemError.serverError("Device registration failed")
            }
            log.info("RegisterDevice success")
        },
        claimStatus: { claimId, claimToken in
            @Dependency(\.offerRedeemConfig) var config
            let log = Logger(subsystem: config.loggerSubsystem, category: "Coupon")
            guard let encodedClaimId = claimId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
                  let url = URL(string: "\(config.baseURL)/api/offers/public/claims/\(encodedClaimId)/status")
            else {
                throw OfferRedeemError.networkError("Invalid URL for claim status")
            }
            var request = URLRequest(url: url)
            request.setValue("Bearer \(claimToken)", forHTTPHeaderField: "Authorization")
            log.info("ClaimStatus: claimId=\(claimId)")
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw OfferRedeemError.networkError("Invalid response")
            }
            return try decodeOrThrow(OfferStatusResponse.self, from: data, httpResponse: httpResponse, log: log)
        },
        checkAvailability: { campaignSlug in
            @Dependency(\.offerRedeemConfig) var config
            let log = Logger(subsystem: config.loggerSubsystem, category: "Coupon")
            guard let url = URL(string: "\(config.baseURL)/api/offers/public/campaigns/\(campaignSlug)/availability") else {
                throw OfferRedeemError.networkError("Invalid URL for availability check")
            }
            log.info("CheckAvailability: slug=\(campaignSlug)")
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw OfferRedeemError.networkError("Invalid response")
            }
            if httpResponse.statusCode == 404 {
                // Campaign not found — assume unavailable
                return OfferAvailabilityResponse(available: false, remaining: 0)
            }
            return try decodeOrThrow(OfferAvailabilityResponse.self, from: data, httpResponse: httpResponse, log: log)
        }
    )
}
