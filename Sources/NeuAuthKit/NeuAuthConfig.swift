import Foundation

/// Configuration for a NeuAuth tenant/app pairing.
///
/// Every value is injected by the consuming app — this package ships **no**
/// hardcoded app identifiers, URLs, or keychain names.
public struct NeuAuthConfig: Sendable, Equatable {
    /// Base URL of the NeuAuth server (e.g. `https://neuauth.byalif.app`).
    public let issuerBaseURL: URL
    /// The tenant's OAuth2 client identifier. Sent on every request as the
    /// `X-Client-ID` header so NeuAuth can resolve the tenant on
    /// unauthenticated flows.
    public let clientID: String
    /// Space-separated OIDC scopes (e.g. `"openid profile email"`).
    public let scopes: String

    public init(issuerBaseURL: URL, clientID: String, scopes: String) {
        self.issuerBaseURL = issuerBaseURL
        self.clientID = clientID
        self.scopes = scopes
    }
}
