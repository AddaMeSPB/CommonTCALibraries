import SwiftUI

extension Color {
    public init(dynamicProvider: @escaping (UITraitCollection) -> Color) {
        self = Self(UIColor { UIColor(dynamicProvider($0)) })
    }
}

extension Color {
    /// Creates a color from a hexadecimal value.
    /// - Parameter hex: The hexadecimal color value.
    /// - Returns: A `Color` instance representing the color.
    /// Color.hex(0xd4deb1)
    public static func hex(_ hex: UInt) -> Self {
        Self(
          red: Double((hex & 0xff0000) >> 16) / 255,
          green: Double((hex & 0x00ff00) >> 8) / 255,
          blue: Double(hex & 0x0000ff) / 255,
          opacity: 1
        )
    }
}

extension Color {
    public static let adaptiveWhite = Self {
        $0.userInterfaceStyle == .dark ? .lpgBlack : .white
    }
    public static let adaptiveBlack = Self {
        $0.userInterfaceStyle == .dark ? .white : Color.lpgBlack
    }

    public static let lpgBlack = hex(0x121212)
    public static let isowordsOrange = hex(0xEAA980)
    public static let isowordsRed = hex(0xE1685C)
    public static let isowordsYellow = hex(0xF3E7A2)

}

extension Color {

    public static let yellowLPG = hex(0xFFE072)

    public static let blueSkyLightLPG = hex(0xAAC8FE)

    public static let nevyDarkLPG = Self {
        $0.userInterfaceStyle == .dark ? .white : hex(0x29356B)
    }


    public static let pinkReddishLPG = hex(0xFF9494)

    public static let offWhiteLPG = hex(0xF1F6FA)

}
