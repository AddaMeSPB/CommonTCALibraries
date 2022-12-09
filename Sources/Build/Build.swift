import Dependencies
import UIKit
import Foundation
import Tagged
import XCTestDynamicOverlay

public struct Build {
  public var gitSha: () -> String
  public var number: () -> Number
  public var identifier: () -> String
  public var identifierForVendor: () -> String

  public typealias Number = Tagged<((), number: ()), Int>

  public init(
    gitSha: @escaping () -> String,
    number: @escaping () -> Number,
    identifier: @escaping () -> String,
    identifierForVendor: @escaping () -> String
  ) {
    self.gitSha = gitSha
    self.number = number
    self.identifier = identifier
      self.identifierForVendor = identifierForVendor
  }
}

extension DependencyValues {
  public var build: Build {
    get { self[Build.self] }
    set { self[Build.self] = newValue }
  }
}

extension Build: TestDependencyKey {
  public static let previewValue = Self.noop

  public static let testValue = Self(
    gitSha: XCTUnimplemented("\(Self.self).gitSha", placeholder: "deadbeef"),
    number: XCTUnimplemented("\(Self.self).number", placeholder: 0),
    identifier: XCTUnimplemented("\(Self.self).identifier", placeholder: "com.addame.test"),
    identifierForVendor: XCTUnimplemented("\(Self.self).identifierForVendor", placeholder: "some_identifierForVendor")
  )
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
    identifierForVendor: { UIDevice.current.identifierForVendor!.uuidString }
  )
}

extension Build {
  public static let noop = Self(
    gitSha: { "deadbeef" },
    number: { 0 },
    identifier: { Bundle.main.bundleIdentifier ?? "" },
    identifierForVendor: { UIDevice.current.identifierForVendor?.uuidString ?? "" }
  )
}
