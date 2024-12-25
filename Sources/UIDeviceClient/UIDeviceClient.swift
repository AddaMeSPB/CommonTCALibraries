import Foundation
import UIKit
import Dependencies
import DependenciesMacros

@DependencyClient
public struct UIDeviceClient: Sendable {
  public var deviceName: @Sendable () async -> String = { "" }
  public var systemName: @Sendable () async -> String = { "" }
  public var systemVersion: @Sendable () async -> String = { "" }
  public var model: @Sendable () async -> String = { "" }
}

// Dependency key for UIDeviceClient
extension UIDeviceClient: @preconcurrency DependencyKey {

    @MainActor
    public static let liveValue: Self = .init(
        deviceName: {
            await MainActor.run { UIDevice.current.name }
        },
        systemName: {
            await MainActor.run { UIDevice.current.systemName }
        },
        systemVersion: {
            await MainActor.run { UIDevice.current.systemVersion }
        },
        model: {
            await MainActor.run { UIDevice.current.model }
        }
    )

    public static let testValue: UIDeviceClient = Self(
        deviceName: { "" },
        systemName: { "" },
        systemVersion: { "" },
        model: { "" }
    )
}

extension DependencyValues {
    public var deviceClient: UIDeviceClient {
        get { self[UIDeviceClient.self] }
        set { self[UIDeviceClient.self] = newValue }
    }
}
