import Combine
import ComposableArchitecture
import Foundation
import UIKit
import Dependencies


@available(iOSApplicationExtension, unavailable)
extension UIApplicationClient: @preconcurrency DependencyKey {
  @MainActor
  public static let liveValue = Self(
    alternateIconNameAsync: { @MainActor in UIApplication.shared.alternateIconName },
    open: { @MainActor url, options in
      await UIApplication.shared.open(url, options: options)
    },
    openSettingsURLString: { UIApplication.openSettingsURLString },
    setAlternateIconName: { @MainActor name in
      try await UIApplication.shared.setAlternateIconName(name)
    },
    setUserInterfaceStyle: { @MainActor userInterfaceStyle in
      await MainActor.run {
        guard
          let scene = UIApplication.shared.connectedScenes.first(where: { $0 is UIWindowScene })
            as? UIWindowScene
        else { return }
        scene.keyWindow?.overrideUserInterfaceStyle = userInterfaceStyle
      }
    },
    supportsAlternateIconsAsync: { @MainActor in UIApplication.shared.supportsAlternateIcons }
  )
}

