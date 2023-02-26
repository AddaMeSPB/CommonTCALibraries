import AdSupport
import AppTrackingTransparency

public struct IDFAClient {
    public var requestAuthorization:  @Sendable () async -> ATTrackingManager.AuthorizationStatus
}
