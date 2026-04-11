import Foundation

/// Localizable strings for the OfferRedeem feature.
/// Each app overrides with its own localized values.
/// Defaults are provided in English.
public struct OfferRedeemStrings: Equatable, Sendable {
    public var invalidEmail: String
    public var alreadyClaimed: String
    public var enterFullCode: String
    public var claimRegistered: String
    public var couponSentToEmail: String
    public var success: String

    public init(
        invalidEmail: String = "Please enter a valid email address.",
        alreadyClaimed: String = "You already have an active claim.",
        enterFullCode: String = "Please enter the full 6-digit verification code.",
        claimRegistered: String = "Your claim has been registered.",
        couponSentToEmail: String = "Your coupon code has been sent to your email.",
        success: String = "Your offer has been redeemed successfully!"
    ) {
        self.invalidEmail = invalidEmail
        self.alreadyClaimed = alreadyClaimed
        self.enterFullCode = enterFullCode
        self.claimRegistered = claimRegistered
        self.couponSentToEmail = couponSentToEmail
        self.success = success
    }

    public static let defaults = OfferRedeemStrings()
}
