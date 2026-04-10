import SwiftUI

struct DelightPopupTheme {
    let primary: Color
    let onPrimary: Color
    let surface: Color
    let radius: CGFloat
    let fontScale: CGFloat

    static let `default` = DelightPopupTheme(
        primary: .blue,
        onPrimary: .white,
        surface: .white,
        radius: 16,
        fontScale: 1.0
    )

    static func fromDTO(_ dto: DelightThemeDTO?) -> DelightPopupTheme {
        guard let dto else { return .default }
        return DelightPopupTheme(
            primary: colorFromHex(dto.primaryHex, fallback: DelightPopupTheme.default.primary),
            onPrimary: colorFromHex(dto.onPrimaryHex, fallback: DelightPopupTheme.default.onPrimary),
            surface: colorFromHex(dto.surfaceHex, fallback: DelightPopupTheme.default.surface),
            radius: CGFloat(clamp(dto.radiusDp ?? 16, min: 0, max: 24)),
            fontScale: CGFloat(clamp(dto.fontScale ?? 1.0, min: 0.85, max: 1.15))
        )
    }

    private static func clamp(_ value: Double, min: Double, max: Double) -> Double {
        Swift.max(min, Swift.min(max, value))
    }

    private static func colorFromHex(_ hex: String?, fallback: Color) -> Color {
        guard let hex else { return fallback }
        let cleaned = hex.replacingOccurrences(of: "#", with: "")
        guard cleaned.count == 6, let value = Int(cleaned, radix: 16) else {
            return fallback
        }
        let red = Double((value >> 16) & 0xFF) / 255.0
        let green = Double((value >> 8) & 0xFF) / 255.0
        let blue = Double(value & 0xFF) / 255.0
        return Color(red: red, green: green, blue: blue)
    }
}
