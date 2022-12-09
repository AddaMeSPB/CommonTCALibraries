
public struct VerifyReceiptEnvelope: Codable, Equatable {
  public let verifiedProductIds: [String]

  public init(verifiedProductIds: [String]) {
    self.verifiedProductIds = verifiedProductIds
  }
}

extension VerifyReceiptEnvelope {
    static public let empty: VerifyReceiptEnvelope = .init(verifiedProductIds: [""])
}
