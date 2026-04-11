import Dependencies

extension OfferRedeemClient: TestDependencyKey {
    public static let testValue = OfferRedeemClient()
    public static let previewValue = testValue
}
