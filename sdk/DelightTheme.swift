import SwiftUI

struct DelightPopupTheme {
    let primary: Color
    let onPrimary: Color
    let surface: Color
    let overlay: Color
    let radius: CGFloat
    let fontScale: CGFloat

    static let `default` = DelightPopupTheme(
        primary: .blue,
        onPrimary: .white,
        surface: .white,
        overlay: Color.black.opacity(0.5),
        radius: 16,
        fontScale: 1.0
    )

    static func fromBrandTheme(_ dto: DelightPopupThemeConfigDTO?) -> DelightPopupTheme {
        let borderRadius = parsePixelValue(dto?.widgetContainer?.borderRadius)
            ?? parsePixelValue(dto?.cta?.borderRadius)
            ?? 16
        return DelightPopupTheme(
            primary: colorFromCss(dto?.cta?.backgroundColor, fallback: DelightPopupTheme.default.primary),
            onPrimary: colorFromCss(dto?.cta?.color, fallback: DelightPopupTheme.default.onPrimary),
            surface: colorFromCss(dto?.widgetContainer?.backgroundColor, fallback: DelightPopupTheme.default.surface),
            overlay: colorFromCss(dto?.overlay?.backgroundColor, fallback: DelightPopupTheme.default.overlay),
            radius: CGFloat(clamp(borderRadius, min: 0, max: 24)),
            fontScale: 1.0
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

    private static func colorFromCss(_ css: String?, fallback: Color) -> Color {
        guard let css else { return fallback }
        let value = css.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if value.hasPrefix("#") {
            return colorFromHex(value, fallback: fallback)
        }
        if value.hasPrefix("rgba("), value.hasSuffix(")") {
            let raw = value
                .replacingOccurrences(of: "rgba(", with: "")
                .replacingOccurrences(of: ")", with: "")
            let components = raw.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            if components.count == 4,
               let red = Double(components[0]),
               let green = Double(components[1]),
               let blue = Double(components[2]),
               let alpha = Double(components[3]) {
                return Color(
                    red: red / 255.0,
                    green: green / 255.0,
                    blue: blue / 255.0,
                    opacity: alpha
                )
            }
        }
        return fallback
    }

    private static func parsePixelValue(_ value: String?) -> Double? {
        guard let value else { return nil }
        let cleaned = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "px", with: "")
        return Double(cleaned)
    }
}
