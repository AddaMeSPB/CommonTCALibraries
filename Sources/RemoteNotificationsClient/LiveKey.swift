import Dependencies
import UIKit

@available(iOSApplicationExtension, unavailable)
extension RemoteNotificationsClient: DependencyKey {
  public static let liveValue = Self(
    isRegistered: {
      await MainActor.run { UIApplication.shared.isRegisteredForRemoteNotifications }
    },
    register: {
      await MainActor.run { UIApplication.shared.registerForRemoteNotifications() }
    },
    unregister: {
      await MainActor.run { UIApplication.shared.unregisterForRemoteNotifications() }
    }
  )
}
