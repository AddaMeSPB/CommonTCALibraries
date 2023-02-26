import AdSupport
import Dependencies
import FoundationExtension
import XCTestDynamicOverlay
import AppTrackingTransparency

@available(iOS 14, *)
extension IDFAClient {

    public static let authorized = Self(
        requestAuthorization: { .authorized }
    )

    public static let notDetermined = Self(
        requestAuthorization: { .notDetermined }
    )

    public static let restricted = Self(
        requestAuthorization: { .restricted }
    )

    public static let denied = Self(
        requestAuthorization: { .denied }
    )
}

extension IDFAClient: TestDependencyKey {
    public static var testValue: IDFAClient = .init(
        requestAuthorization: XCTUnimplemented("\(Self.self).requestAuthorization is not implemented")
    )
}
