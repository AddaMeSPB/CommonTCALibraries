import Foundation

// MARK: - Response Models

public struct OfferPreclaimResponse: Codable, Equatable, Sendable {
    public let status: String
    public let claim_id: String?
    public let claim_token: String?
    public let requires_verification: Bool?
    public let message: String?
    public let error: String?

    public init(
        status: String, claim_id: String? = nil, claim_token: String? = nil,
        requires_verification: Bool? = nil, message: String? = nil, error: String? = nil
    ) {
        self.status = status
        self.claim_id = claim_id
        self.claim_token = claim_token
        self.requires_verification = requires_verification
        self.message = message
        self.error = error
    }
}

public struct OfferVerifyResponse: Codable, Equatable, Sendable {
    public let status: String?
    public let next_step: String?
    public let claim_token: String?
    public let message: String?
    public let deep_link: String?
    public let code: String?
    public let redemption_url: String?
    public let error: String?
    public let attempts_remaining: Int?

    public init(
        status: String? = nil, next_step: String? = nil, claim_token: String? = nil,
        message: String? = nil, deep_link: String? = nil, code: String? = nil,
        redemption_url: String? = nil, error: String? = nil, attempts_remaining: Int? = nil
    ) {
        self.status = status
        self.next_step = next_step
        self.claim_token = claim_token
        self.message = message
        self.deep_link = deep_link
        self.code = code
        self.redemption_url = redemption_url
        self.error = error
        self.attempts_remaining = attempts_remaining
    }
}

public struct OfferClaimResponse: Codable, Equatable, Sendable {
    public let status: String?
    public let code: String?
    public let redemption_url: String?
    public let message: String?
    public let error: String?

    public init(
        status: String? = nil, code: String? = nil, redemption_url: String? = nil,
        message: String? = nil, error: String? = nil
    ) {
        self.status = status
        self.code = code
        self.redemption_url = redemption_url
        self.message = message
        self.error = error
    }
}

public struct OfferStatusResponse: Codable, Equatable, Sendable {
    public let id: String
    public let status: String
    public let campaign_name: String?
    public let campaign_slug: String?
    public let claim_mode: String?
    public let deep_link_scheme: String?
    public let app_name: String?

    public init(
        id: String, status: String, campaign_name: String? = nil,
        campaign_slug: String? = nil, claim_mode: String? = nil,
        deep_link_scheme: String? = nil, app_name: String? = nil
    ) {
        self.id = id
        self.status = status
        self.campaign_name = campaign_name
        self.campaign_slug = campaign_slug
        self.claim_mode = claim_mode
        self.deep_link_scheme = deep_link_scheme
        self.app_name = app_name
    }
}

/// Campaign availability check (used to hide redeem button when codes exhausted)
public struct OfferAvailabilityResponse: Codable, Equatable, Sendable {
    public let available: Bool
    public let remaining: Int?

    public init(available: Bool, remaining: Int? = nil) {
        self.available = available
        self.remaining = remaining
    }
}

// MARK: - Error

public enum OfferRedeemError: LocalizedError, Equatable, Sendable {
    case serverError(String)
    case networkError(String)

    public var errorDescription: String? {
        switch self {
        case let .serverError(msg): return msg
        case let .networkError(msg): return msg
        }
    }
}
