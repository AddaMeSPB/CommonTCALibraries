import AdSupport
import AppTrackingTransparency
import Dependencies
import DependenciesMacros

@DependencyClient
public struct IDFAClient: Sendable {
  public var requestAuthorization: @Sendable () async -> ATTrackingManager.AuthorizationStatus = { .notDetermined }
}
