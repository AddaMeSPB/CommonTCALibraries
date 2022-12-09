import Dependencies
import XCTestDynamicOverlay

extension DependencyValues {
    public var userNotifications: UserNotificationClient {
        get { self[UserNotificationClient.self] }
        set { self[UserNotificationClient.self] = newValue }
    }
}

extension UserNotificationClient: TestDependencyKey {
  public static let previewValue = Self.noop

  public static let testValue = Self(
    add: XCTUnimplemented("\(Self.self).add"),
    delegate: XCTUnimplemented("\(Self.self).delegate", placeholder: .finished),
    getNotificationSettings: XCTUnimplemented(
      "\(Self.self).getNotificationSettings",
      placeholder: Notification.Settings(authorizationStatus: .notDetermined)
    ),
    deliveredNotifications: XCTUnimplemented("\(Self.self).getDeliveredNotifications"),
    pendingNotifications: XCTUnimplemented("\(Self.self).pendingNotifications") ,
    removeDeliveredNotificationsWithIdentifiers: XCTUnimplemented(
      "\(Self.self).removeDeliveredNotificationsWithIdentifiers"
    ),
    removePendingNotificationRequestsWithIdentifiers: XCTUnimplemented(
        "\(Self.self).removePendingNotificationRequestsWithIdentifiers"
    ),
    removeAllPendingNotificationRequests: XCTUnimplemented(
        "\(Self.self).removeAllPendingNotificationRequests"
    ),
    requestAuthorization: XCTUnimplemented("\(Self.self).requestAuthorization")
  )
}

extension UserNotificationClient {
  public static let noop = Self(
    add: { _ in },
    delegate: { AsyncStream { _ in } },
    getNotificationSettings: { Notification.Settings(authorizationStatus: .notDetermined) },
    deliveredNotifications: { [] },
    pendingNotifications: { [] },
    removeDeliveredNotificationsWithIdentifiers: { _ in },
    removePendingNotificationRequestsWithIdentifiers: { _ in },
    removeAllPendingNotificationRequests: { },
    requestAuthorization: { _ in false }
  )
}
