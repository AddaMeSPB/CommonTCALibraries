import Contacts
import Network
import Dependencies

public struct NetworkPath {
  public var status: NWPath.Status

  public init(status: NWPath.Status) {
    self.status = status
  }
}

extension NetworkPath {
  public init(rawValue: NWPath) {
    status = rawValue.status
  }
}

public struct PathMonitorClient {
  public typealias NPath = @Sendable () -> AsyncStream<NetworkPath>
  public var nPath: NPath

  public init(nPath: @escaping NPath) {
    self.nPath = nPath
  }
}

extension DependencyValues {
    public var pathMonitorClient: PathMonitorClient {
        get { self[PathMonitorClient.self] }
        set { self[PathMonitorClient.self] = newValue }
    }
}
