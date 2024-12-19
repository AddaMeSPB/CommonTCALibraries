import Combine
import UserNotifications
import Dependencies

extension UserNotificationClient: DependencyKey {

  public static let liveValue = Self(
      add: { try await UNUserNotificationCenter.current().add($0) },
      delegate: {
        AsyncStream { continuation in
          let delegate = Delegate(continuation: continuation)
          UNUserNotificationCenter.current().delegate = delegate
          continuation.onTermination = { [delegate = UncheckedSendable(delegate)] _ in
            _ = delegate
          }
        }
      },
      
      getNotificationSettings: {
        await Notification.Settings(
          rawValue: UNUserNotificationCenter.current().notificationSettings()
        )
      },

      deliveredNotifications: {
          let notifications = await UNUserNotificationCenter.current().deliveredNotifications()
          return notifications.map { Notification(date: $0.date, request: $0.request) }
      },

      pendingNotifications: {
          let notifications = await UNUserNotificationCenter.current().pendingNotificationRequests()
          return notifications.map { Notification.init(date: Date(), request: $0) }
      },

      removeDeliveredNotificationsWithIdentifiers: {
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: $0)
      },

      removePendingNotificationRequestsWithIdentifiers: {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: $0)
      },
      
      removeAllPendingNotificationRequests: {
          UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
      },
      
      requestAuthorization: {
        try await UNUserNotificationCenter.current().requestAuthorization(options: $0)
      }
    )
}

extension UserNotificationClient.Notification {
  public init(rawValue: UNNotification) {
    self.date = rawValue.date
    self.request = rawValue.request
  }
}

extension UserNotificationClient.Notification.Response {
  public init(rawValue: UNNotificationResponse) {
    self.notification = .init(rawValue: rawValue.notification)
  }
}

extension UserNotificationClient.Notification.Settings {
  public init(rawValue: UNNotificationSettings) {
    self.authorizationStatus = rawValue.authorizationStatus
  }
}

extension UserNotificationClient {
  fileprivate class Delegate: NSObject, UNUserNotificationCenterDelegate {
    var continuation: AsyncStream<UserNotificationClient.DelegateEvent>.Continuation

    init(continuation: AsyncStream<UserNotificationClient.DelegateEvent>.Continuation) {
      self.continuation = continuation
    }

    //    // Update didReceive with async
    func userNotificationCenter(
      _ center: UNUserNotificationCenter,
      didReceive response: UNNotificationResponse
    ) async {
        // Yield the event to the continuation
        self.continuation.yield(.didReceiveResponse(.init(rawValue: response)))
    }

    func userNotificationCenter(
      _ center: UNUserNotificationCenter,
      openSettingsFor notification: UNNotification?
    ) {
      self.continuation.yield(
        .openSettingsForNotification(notification.map(Notification.init(rawValue:)))
      )
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        // Yield the willPresentNotification event with the notification safely
        self.continuation.yield(.willPresentNotification(.init(rawValue: notification)))
        // Now you can decide what the presentation options should be
        // For example, you could return specific options
        return [.banner, .sound] // Example options
    }
  }
}
