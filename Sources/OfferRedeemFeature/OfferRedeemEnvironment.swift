import Foundation

/// App-specific configuration for the OfferRedeem feature.
/// Passed into the reducer's State at init time.
public struct OfferRedeemEnvironment: Equatable, Sendable {
    public var campaignSlug: String
    /// User-visible display name (e.g., "Photo Cleanup Pro"). Distinct from `OfferRedeemConfig.appSlug` which is the API identifier.
    public var appName: String
    public var privacyURL: URL
    public var termsURL: URL

    public init(
        campaignSlug: String,
        appName: String,
        privacyURL: URL,
        termsURL: URL
    ) {
        self.campaignSlug = campaignSlug
        self.appName = appName
        self.privacyURL = privacyURL
        self.termsURL = termsURL
    }
}
