
public struct ReceiptFinalizationEnvelope: Equatable {
    public let transactions: [StoreKitClient.PaymentTransaction]
    public let verifyEnvelope: VerifyReceiptEnvelope

    public init(
        transactions: [StoreKitClient.PaymentTransaction],
        verifyEnvelope: VerifyReceiptEnvelope
    ) {
        self.transactions = transactions
        self.verifyEnvelope = verifyEnvelope
    }
}
