//import UIKit
import Tagged
import SwiftUI
import Foundation
import Dependencies
import DependenciesMacros

public struct Build: Sendable {
  public var gitSha: @Sendable () -> String = { "" }
  public var number: @Sendable () -> Number = { 0 }
  public var identifier: @Sendable () -> String = { "" }
  public var identifierForVendor: @Sendable () -> String = { "" }

  public typealias Number = Tagged<((), number: ()), Int>

}

extension DependencyValues {
    public var build: Build {
        get { self[Build.self] }
        set { self[Build.self] = newValue }
    }
}

extension Build: TestDependencyKey {
    public static let previewValue = Self.noop
    public static let testValue = Self()
}

extension Build: DependencyKey {
    public static let liveValue = Self(
        gitSha: { Bundle.main.infoDictionary?["GitSHA"] as? String ?? "" },
        number: {
            .init(
                rawValue: (Bundle.main.infoDictionary?["CFBundleVersion"] as? String)
                    .flatMap(Int.init)
                ?? 0
            )
        },
        identifier: { Bundle.main.bundleIdentifier ?? "" },
        identifierForVendor: {
            Task {
                await MainActor.run {
                    // Safely access UIDevice properties on the main actor
                    guard let vendorID = UIDevice.current.identifierForVendor?.uuidString else {
                        // Report the error
                        fatalError("No identifierForVendor found.")
                    }
                    return vendorID
                }
            }
            return "" // Default case in case Task hasn't completed yet
        }
    )
}

extension Build {
    public static let noop = Self(
        gitSha: { "" },
        number: { 0 },
        identifier: { Bundle.main.bundleIdentifier ?? "" },
        identifierForVendor: { "" }
    )
}

