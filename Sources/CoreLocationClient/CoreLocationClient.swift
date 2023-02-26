import CoreLocation
import Dependencies
import XCTestDynamicOverlay
import CoreLocation

public struct CoreLocationClient {
    public var authorizationStatus: @Sendable () -> CLAuthorizationStatus
    public var delegate: @Sendable () -> AsyncStream<LocationManagerDelegate.Action>
    public var requestLocation: @Sendable () -> ()
    public var requestWhenInUseAuthorization: @Sendable () -> ()
}

public final class LocationManagerDelegate: NSObject, CLLocationManagerDelegate {
    public let continuation: AsyncStream<Action>.Continuation

    public init(
        continuation: AsyncStream<Action>.Continuation
    ) {
        self.continuation = continuation
    }

    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        continuation.yield(.didFailWithError(error as NSError))
    }

    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        continuation.yield(
            .didUpdateLocations(locations)
        )
    }

    public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        continuation.yield(.didChangeAuthorization)
    }
}

extension LocationManagerDelegate {
    public enum Action: Equatable {
        case didChangeAuthorization
        case didFailWithError(NSError)
        case didUpdateLocations([CLLocation])
    }
}

extension CoreLocationClient: DependencyKey {
    static public var liveValue: Self {
        let manager = CLLocationManager()

        return Self(
            authorizationStatus: { manager.authorizationStatus },
            delegate: {
                AsyncStream { continuation in
                    let delegate = LocationManagerDelegate(continuation: continuation)
                    manager.delegate = delegate
                    continuation.onTermination = { [delegate] _ in
                        _ = delegate
                    }
                }
            },
            requestLocation: {
                manager.startUpdatingLocation()
//                        manager.allowsBackgroundLocationUpdates = true
//                        manager.pausesLocationUpdatesAutomatically = false
//                        manager.desiredAccuracy = kCLLocationAccuracyBest
//                        manager.distanceFilter = 20.0 // 20.0 meters

            },
            requestWhenInUseAuthorization: { manager.requestWhenInUseAuthorization() }
        )
    }
}

extension DependencyValues {
    public var coreLocationClient: CoreLocationClient {
        get { self[CoreLocationClient.self]  }
        set { self[CoreLocationClient.self] = newValue }
    }
}

