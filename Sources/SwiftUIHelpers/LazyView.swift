import SwiftUI

public struct LazyView<Content: View>: View {
  public let build: () -> Content

  public init(_ build: @autoclosure @escaping () -> Content) {
    self.build = build
  }

  public var body: Content {
    build()
  }
}
