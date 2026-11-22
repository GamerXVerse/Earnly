import SwiftUI
import UIKit

/// Semantic color tokens. Brand values come from the Earnly brand reference;
/// supporting values are neutral tints chosen to sit next to the brand purple.
enum EarnlyColor {
    // Brand
    static let brand = Color(hex: 0x6155F5)
    /// Brand purple as text/icon on the canvas. Lightened in dark mode for contrast.
    static let brandText = Color.dynamic(light: 0x6155F5, dark: 0x9A91FF)
    static let brandTint = Color.dynamic(light: 0xEFEDFE, dark: 0x25224D)
    static let success = Color(hex: 0xA5F2C3)
    /// Success as text/icon on the canvas (mint itself is too light on white).
    static let successText = Color.dynamic(light: 0x0B7A43, dark: 0xA5F2C3)
    static let successTint = Color.dynamic(light: 0xE7FAEF, dark: 0x143427)

    // Neutrals
    static let ink = Color.dynamic(light: 0x141422, dark: 0xF4F4FA)
    static let inkSecondary = Color.dynamic(light: 0x5C5D72, dark: 0xA6A7BC)
    static let canvas = Color.dynamic(light: 0xF6F7FB, dark: 0x0E0E16)
    static let surface = Color.dynamic(light: 0xFFFFFF, dark: 0x181826)
    static let separator = Color.dynamic(light: 0xE2E3EE, dark: 0x2B2B3E)
    static let outline = Color.dynamic(light: 0xD5D6E4, dark: 0x3A3A52)

    // State
    static let disabledFill = Color.dynamic(light: 0xE2E3EE, dark: 0x2B2B3E)
    static let disabledText = Color.dynamic(light: 0x8B8CA0, dark: 0x6F7087)
    static let error = Color.dynamic(light: 0xC62A45, dark: 0xFF7A8E)
    static let errorTint = Color.dynamic(light: 0xFDECEF, dark: 0x3A1A22)
    static let onBrand = Color.white
    /// Dark ink used on top of mint surfaces in both appearances.
    static let onSuccess = Color(hex: 0x141422)
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }

    static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(uiColor: UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}
