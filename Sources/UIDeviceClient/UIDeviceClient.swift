import Foundation
import UIKit
import Dependencies
import DependenciesMacros

@DependencyClient
public struct UIDeviceClient: Sendable {
  public var identifierForVendor: @Sendable () async -> String? = { nil }
  public var deviceName: @Sendable () async -> String = { "" }
  public var systemName: @Sendable () async -> String = { "" }
  public var systemVersion: @Sendable () async -> String = { "" }
  public var model: @Sendable () async -> String = { "" }
}

// Dependency key for UIDeviceClient
extension UIDeviceClient: @preconcurrency DependencyKey {

  public static let liveValue: Self = .init(
    identifierForVendor: {
      await withUnsafeContinuation { continuation in
        DispatchQueue.main.async {
          continuation.resume(returning: UIDevice.current.identifierForVendor?.uuidString)
        }
      }
    },

    deviceName: {
      await withUnsafeContinuation { continuation in
        DispatchQueue.main.async {
          continuation.resume(returning: UIDevice.current.name)
        }
      }
    },
    systemName: {
      await withUnsafeContinuation { continuation in
        DispatchQueue.main.async {
          continuation.resume(returning: UIDevice.current.systemName)
        }
      }
    },
    systemVersion: {
      await withUnsafeContinuation { continuation in
        DispatchQueue.main.async {
          continuation.resume(returning: UIDevice.current.systemVersion)
        }
      }
    },
    model: {
      await withUnsafeContinuation { continuation in
        DispatchQueue.main.async {
          continuation.resume(returning: UIDevice.current.model)
        }
      }
    }
  )

  public static let testValue: UIDeviceClient = Self(
    identifierForVendor: { nil },
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
