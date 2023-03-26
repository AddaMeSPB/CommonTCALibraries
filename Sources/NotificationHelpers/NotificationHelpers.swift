import Combine
import ComposableArchitecture
import ComposableUserNotifications
import RemoteNotificationsClient

public func registerForRemoteNotificationsAsync(
  remoteNotifications: RemoteNotificationsClient,
  userNotifications: UserNotificationClient
) async {
  let settings = await userNotifications.getNotificationSettings()
  guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
  else { return }
  await remoteNotifications.register()
}

public func unregisterForRemoteNotificationsAsync(
  remoteNotifications: RemoteNotificationsClient,
  userNotifications: UserNotificationClient
) async {
  let settings = await userNotifications.getNotificationSettings()
  guard settings.authorizationStatus == .notDetermined
            || settings.authorizationStatus == .denied
  else { return }
  await remoteNotifications.unregister()
}
