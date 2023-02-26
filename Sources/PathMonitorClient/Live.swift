import Network
import Dependencies
import Foundation

extension PathMonitorClient: DependencyKey {
    static public var liveValue: Self = .init {
        AsyncStream { continuation in
            let monitor = NWPathMonitor()
            monitor.pathUpdateHandler = { path in
                continuation.yield(NetworkPath.init(rawValue: path))
            }
            continuation.onTermination = { _ in
                monitor.cancel()
            }
            monitor.start(queue: DispatchQueue(label: "NSPathMonitor.paths"))
        }
    }
}
