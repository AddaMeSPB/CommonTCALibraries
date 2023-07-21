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
          continuation.onTermination = { [delegate] _ in }
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

//          client.pendingNotificationRequests = {
//            let requests = await center.pendingNotificationRequests()
//            return requests.map(Notification.Request.init(rawValue:))
//          }

      },

//      #if os(iOS) || os(macOS) || targetEnvironment(macCatalyst)
//      client.getDeliveredNotifications = {
//        .future { callback in
//          center.getDeliveredNotifications { notifications in
//            callback(.success(notifications.map(Notification.init(rawValue:))))
//          }
//        }
//      }
//      #endif

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
    let continuation: AsyncStream<UserNotificationClient.DelegateEvent>.Continuation

    init(continuation: AsyncStream<UserNotificationClient.DelegateEvent>.Continuation) {
      self.continuation = continuation
    }

    func userNotificationCenter(
      _ center: UNUserNotificationCenter,
      didReceive response: UNNotificationResponse,
      withCompletionHandler completionHandler: @escaping () -> Void
    ) {
      self.continuation.yield(
        .didReceiveResponse(.init(rawValue: response)) { completionHandler() }
      )
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
      willPresent notification: UNNotification,
      withCompletionHandler completionHandler:
        @escaping (UNNotificationPresentationOptions) -> Void
    ) {
      self.continuation.yield(
        .willPresentNotification(.init(rawValue: notification)) { completionHandler($0) }
      )
    }
  }
}

