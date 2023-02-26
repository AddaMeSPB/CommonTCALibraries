import SwiftUI

public struct Preview<Content: View>: View {
  public let content: Content

  public init(@ViewBuilder _ content: () -> Content) {
    self.content = content()
  }

  public var body: some View {
    Group {
      self.content
        .environment(\.colorScheme, .light)
        .preferredColorScheme(.light)
        .navigationBarHidden(true)
        .previewDevice("iPhone 12")
        .previewDisplayName("Pro, light mode")

      self.content
        .environment(\.colorScheme, .dark)
        .preferredColorScheme(.dark)
        .navigationBarHidden(true)
        .previewDevice("iPhone 14")
        .previewDisplayName("Mini, dark mode")
    }
  }
}
