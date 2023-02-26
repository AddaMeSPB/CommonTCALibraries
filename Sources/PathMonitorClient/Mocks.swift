import Foundation
import Network
import Dependencies
import XCTestDynamicOverlay
import FoundationExtension

extension AsyncStream {
  public static var never: Self {
    Self { _ in }
  }
}

extension PathMonitorClient {
    static public let noop = Self(
        nPath: { AsyncStream.never }
    )

    static public let satisfied = Self(
        nPath: { .init { continuation in continuation.yield(NetworkPath(status: .satisfied)) } }
    )

    static public let unsatisfied = Self(
        nPath: { .init { continuation in continuation.yield(NetworkPath(status: .unsatisfied)) } }
    )

    static public let flakey = Self(
        nPath: { .init { continuation in
            Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { flip in
                var status = NetworkPath(status: .satisfied).status == .satisfied
                    ? NetworkPath(status: .unsatisfied)
                    : NetworkPath(status: .satisfied)
                    continuation.yield(status)
                }
            }
        }
    )
}

extension PathMonitorClient: TestDependencyKey {
    static public var testValue: PathMonitorClient = .init(
        nPath: XCTUnimplemented("\(Self.self).nPath")
    )
}
