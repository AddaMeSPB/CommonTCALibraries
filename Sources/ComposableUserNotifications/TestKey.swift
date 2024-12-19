import Dependencies

extension DependencyValues {
    public var userNotifications: UserNotificationClient {
        get { self[UserNotificationClient.self] }
        set { self[UserNotificationClient.self] = newValue }
    }
}

extension UserNotificationClient: TestDependencyKey {
  public static let previewValue = Self.noop

  public static let testValue = Self()
}

extension UserNotificationClient {
    public static let noop = Self(
        add: { _ in },
        delegate: { .finished },
        getNotificationSettings: {
            Notification.Settings(authorizationStatus: .notDetermined)
        },
        deliveredNotifications: {
            []
        },
        pendingNotifications: {
            []
        },
        removeDeliveredNotificationsWithIdentifiers: { _ in },
        removePendingNotificationRequestsWithIdentifiers: { _ in },
        removeAllPendingNotificationRequests: { },
        requestAuthorization: { _ in
            false // or throw an error if you prefer to signal failure
        }
    )
}
