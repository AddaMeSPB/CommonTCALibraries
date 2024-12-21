import Contacts
import Network
import Dependencies
import DependenciesMacros

public struct NetworkPath: Sendable {
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

@DependencyClient
public struct PathMonitorClient: Sendable {
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
