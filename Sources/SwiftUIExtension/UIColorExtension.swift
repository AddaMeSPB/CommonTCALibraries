#if canImport(UIKit)

import UIKit

extension UIColor {
    public static func hex(_ hex: UInt) -> Self {
        Self(
            red: CGFloat((hex & 0xFF0000) >> 16) / 255,
            green: CGFloat((hex & 0x00FF00) >> 8) / 255,
            blue: CGFloat(hex & 0x0000FF) / 255,
            alpha: 1
        )
    }
}

#elseif canImport(AppKit)

import AppKit

extension NSColor {
    public static func hex(_ hex: UInt) -> Self {
        Self(
            red: CGFloat((hex & 0xFF0000) >> 16) / 255,
            green: CGFloat((hex & 0x00FF00) >> 8) / 255,
            blue: CGFloat(hex & 0x0000FF) / 255,
            alpha: 1
        )
    }
}

#endif

