import Dependencies

#if canImport(UIKit)

import UIKit

@available(iOSApplicationExtension, unavailable)
extension RemoteNotificationsClient: DependencyKey {
    public static let liveValue = Self(
        isRegistered: {
          UIApplication.shared.isRegisteredForRemoteNotifications
        },
        register: {
          UIApplication.shared.registerForRemoteNotifications()
        },
        unregister: {
          UIApplication.shared.unregisterForRemoteNotifications()
        }
    )
}
#endif
