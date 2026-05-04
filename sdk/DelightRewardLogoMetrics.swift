import Foundation

/// Reward badge layout derived from `popup.theme.rewardLogo` (kept out of `DelightConfigDTO` so SwiftUI templates
/// don’t depend on optional extension members across out-of-sync SDK checkouts).
enum DelightRewardLogoMetrics {
    static func badgeDiameter(for config: DelightConfigDTO) -> CGFloat {
        CGFloat(badgeDiameterPoints(for: config))
    }

    static func outerInsets(for config: DelightConfigDTO) -> DelightComponentInsets {
        let m = config.popup?.theme?.rewardLogo?.margin
        let sideMargins = spacingInsets(m)
        let marginLeftRaw = parsePixel(m?.left)
        let leading: Double
        if let marginLeftRaw, marginLeftRaw > 0 {
            leading = marginLeftRaw
        } else if let themeLeft = parsePixel(config.popup?.theme?.rewardLogo?.left) {
            leading = themeLeft
        } else {
            leading = 14
        }
        let themeTop = parsePixel(config.popup?.theme?.rewardLogo?.top) ?? 0
        return DelightComponentInsets(
            top: sideMargins.top + themeTop,
            right: sideMargins.right,
            bottom: sideMargins.bottom,
            left: leading
        )
    }

    private static func badgeDiameterPoints(for config: DelightConfigDTO) -> Double {
        let fallbackHeight = parsePixel(config.popup?.theme?.rewardLogo?.height) ?? 48
        let w = parsePixel(config.popup?.theme?.rewardLogo?.width)
            ?? parsePixel(config.popup?.theme?.rewardLogo?.maxWidth)
        let h = parsePixel(config.popup?.theme?.rewardLogo?.height)
            ?? parsePixel(config.popup?.theme?.rewardLogo?.maxHeight)
        let d: Double
        if let w, let h {
            d = min(w, h)
        } else if let w {
            d = w
        } else if let h {
            d = h
        } else {
            d = fallbackHeight
        }
        return min(max(d, 48), 72)
    }

    private static func spacingInsets(_ spacing: DelightSpacingDTO?) -> DelightComponentInsets {
        DelightComponentInsets(
            top: parsePixel(spacing?.top) ?? 0,
            right: parsePixel(spacing?.right) ?? 0,
            bottom: parsePixel(spacing?.bottom) ?? 0,
            left: parsePixel(spacing?.left) ?? 0
        )
    }

    private static func parsePixel(_ value: String?) -> Double? {
        guard let value else { return nil }
        let cleaned = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "px", with: "")
        return Double(cleaned)
    }
}
