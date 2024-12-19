import Combine
import Dependencies
@preconcurrency import UserNotifications
import DependenciesMacros
import ComposableArchitecture

@DependencyClient
public struct UserNotificationClient: Sendable {
  public var add: @Sendable (UNNotificationRequest) async throws -> Void
  public var delegate: @Sendable () -> AsyncStream<DelegateEvent> = { .finished }
  public var getNotificationSettings: @Sendable () async -> Notification.Settings = {
    Notification.Settings(authorizationStatus: .notDetermined)
  }
  public var deliveredNotifications: @Sendable () async -> [Notification] = { [] }
  public var pendingNotifications: @Sendable () async -> [Notification] = { [] }

  public var removeDeliveredNotificationsWithIdentifiers: @Sendable ([String]) async -> Void
  public var removePendingNotificationRequestsWithIdentifiers: @Sendable ([String]) async -> Void
  public var removeAllPendingNotificationRequests: @Sendable () async -> Void
  public var requestAuthorization: @Sendable (UNAuthorizationOptions) async throws -> Bool

  @CasePathable
  public enum DelegateEvent {
    case didReceiveResponse(Notification.Response)
    case openSettingsForNotification(Notification?)
    case willPresentNotification(Notification)
  }

  public struct Notification: Equatable, Sendable {
    public var date: Date
    public var request: UNNotificationRequest

    public init(
      date: Date,
      request: UNNotificationRequest
    ) {
      self.date = date
      self.request = request
    }

    public struct Response: Equatable, Sendable {
      public var notification: Notification

      public init(notification: Notification) {
        self.notification = notification
      }
    }

    // TODO: should this be nested in UserNotificationClient instead of Notification?
    public struct Settings: Equatable {
      public var authorizationStatus: UNAuthorizationStatus

      public init(authorizationStatus: UNAuthorizationStatus) {
        self.authorizationStatus = authorizationStatus
      }
    }
  }
}
