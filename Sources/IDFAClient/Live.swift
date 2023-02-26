
import AdSupport
import AppTrackingTransparency
import Dependencies

@available(iOS 14, *)
extension IDFAClient: DependencyKey {
    static public let liveValue: IDFAClient = .init {
        await withCheckedContinuation { continuation in
            ATTrackingManager.requestTrackingAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }
}

extension DependencyValues {
    public var idfaClient: IDFAClient {
        get { self[IDFAClient.self] }
        set { self[IDFAClient.self] = newValue }
    }
}
