import SwiftUI


#if canImport(UIKit)
  import UIKit

  extension UIColor {
    public func inverted() -> Self {
      Self {
        self.resolvedColor(
          with: .init(userInterfaceStyle: $0.userInterfaceStyle == .dark ? .light : .dark)
        )
      }
    }
  }
#endif
