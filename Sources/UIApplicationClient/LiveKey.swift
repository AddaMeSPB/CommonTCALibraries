import Combine
import ComposableArchitecture
import Foundation
import UIKit
import Dependencies


@available(iOSApplicationExtension, unavailable)
extension UIApplicationClient: @preconcurrency DependencyKey {
  @MainActor
  public static let liveValue = Self(
    alternateIconNameAsync: { UIApplication.shared.alternateIconName },
    open: { @MainActor in await UIApplication.shared.open($0, options: $1) },
    openSettingsURLString: { UIApplication.openSettingsURLString },
    setAlternateIconName: { @MainActor in try await UIApplication.shared.setAlternateIconName($0) },
    setUserInterfaceStyle: { userInterfaceStyle in
      await MainActor.run {
        guard
          let scene = UIApplication.shared.connectedScenes.first(where: { $0 is UIWindowScene })
            as? UIWindowScene
        else { return }
        scene.keyWindow?.overrideUserInterfaceStyle = userInterfaceStyle
      }
    },
    supportsAlternateIconsAsync: { UIApplication.shared.supportsAlternateIcons }
  )
}
