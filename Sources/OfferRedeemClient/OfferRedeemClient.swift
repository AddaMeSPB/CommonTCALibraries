import Dependencies
import DependenciesMacros

@DependencyClient
public struct OfferRedeemClient: Sendable {
    /// Submit email for a preclaim on a campaign
    public var preclaim: @Sendable (
        _ campaignSlug: String,
        _ email: String,
        _ marketingConsent: Bool
    ) async throws -> OfferPreclaimResponse

    /// Verify email with 6-digit code
    public var verify: @Sendable (
        _ claimId: String,
        _ code: String,
        _ claimToken: String
    ) async throws -> OfferVerifyResponse

    /// App-side claim (after email verification)
    public var appClaim: @Sendable (
        _ campaignSlug: String,
        _ claimToken: String
    ) async throws -> OfferClaimResponse

    /// Register this device with the backend
    public var registerDevice: @Sendable () async throws -> Void

    /// Check claim status
    public var claimStatus: @Sendable (
        _ claimId: String,
        _ claimToken: String
    ) async throws -> OfferStatusResponse

    /// Check if codes are available for a campaign (hide redeem button when exhausted)
    public var checkAvailability: @Sendable (
        _ campaignSlug: String
    ) async throws -> OfferAvailabilityResponse
}

// MARK: - DependencyValues

extension DependencyValues {
    public var offerRedeemClient: OfferRedeemClient {
        get { self[OfferRedeemClient.self] }
        set { self[OfferRedeemClient.self] = newValue }
    }
}
