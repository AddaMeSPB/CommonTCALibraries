import Dependencies

/// App-specific configuration for the OfferRedeem system.
/// Each app must register this dependency with its own values.
public struct OfferRedeemConfig: Equatable, Sendable {
    /// App identifier sent to MC backend (e.g., "photocleanup", "subtracker")
    public var appSlug: String

    /// Keychain service name for install token (e.g., "com.byalif.photocleanup.offers")
    public var keychainService: String

    /// OSLog subsystem (e.g., "com.byalif.photocleanup")
    public var loggerSubsystem: String

    /// Mission Control base URL (defaults to production)
    public var baseURL: String

    public init(
        appSlug: String,
        keychainService: String,
        loggerSubsystem: String,
        baseURL: String = "https://mc.byalif.app:9443"
    ) {
        self.appSlug = appSlug
        self.keychainService = keychainService
        self.loggerSubsystem = loggerSubsystem
        self.baseURL = baseURL
    }
}

// MARK: - Dependency Registration

private enum OfferRedeemConfigKey: DependencyKey {
    static let liveValue: OfferRedeemConfig = {
        assertionFailure(
            "offerRedeemConfig not registered. Call withDependencies { $0.offerRedeemConfig = OfferRedeemConfig(...) } in your app."
        )
        return OfferRedeemConfig(
            appSlug: "unset",
            keychainService: "com.byalif.unset.offers",
            loggerSubsystem: "com.byalif.unset"
        )
    }()
    static let testValue = OfferRedeemConfig(
        appSlug: "test-app",
        keychainService: "com.test.offers",
        loggerSubsystem: "com.test"
    )
}

extension DependencyValues {
    public var offerRedeemConfig: OfferRedeemConfig {
        get { self[OfferRedeemConfigKey.self] }
        set { self[OfferRedeemConfigKey.self] = newValue }
    }
}
