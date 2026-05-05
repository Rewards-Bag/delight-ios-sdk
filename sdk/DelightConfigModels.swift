import Foundation

struct DelightConfigDTO: Decodable {
    let partnerId: String?
    let partnerLogo: String?
    let apiUrl: String?
    let language: String?
    let popup: DelightPopupSectionDTO?
}

struct DelightPopupSectionDTO: Decodable {
    let enabled: Bool?
    let defaultLocale: String?
    let locales: [String: DelightPopupLocaleDTO]?
    let theme: DelightPopupThemeConfigDTO?
    let rewards: [DelightPopupRewardDTO]?
}

struct DelightPopupLocaleDTO: Decodable {
    let orderLine: String?
    let cta: String?
    let secondaryCta: String?
    let partnerTerms: String?
    let terms: DelightPopupTermsLocaleDTO?
    let poweredBy: String?
    let privacyPolicy: String?
}

struct DelightPopupTermsLocaleDTO: Decodable {
    let header: String?
}

struct DelightPopupRewardDTO: Decodable {
    let id: String?
    let show: Bool?
    let ctaUrl: String?
    let postPopupMobileImage: String?
    let postPopupWebImage: String?
    let logo: String?
    let partnerTermsUrl: String?
    let privacyPolicyUrl: String?
    let poweredByUrl: String?
    let locales: [String: DelightPopupRewardLocaleDTO]?
    let ticketType: String?
    let ageRequirement: String?
}

struct DelightPopupRewardLocaleDTO: Decodable {
    let headline: String?
    let description: String?
    let ctaHelperText: String?
    let emailDisclaimer: String?
    let terms: String?
    let cta: String?
}

struct DelightPopupThemeConfigDTO: Decodable {
    let overlay: DelightOverlayThemeDTO?
    let widgetContainer: DelightWidgetContainerThemeDTO?
    let widgetContentContainer: DelightWidgetContentContainerThemeDTO?
    let hostLogo: DelightAssetThemeDTO?
    let rewardLogo: DelightAssetThemeDTO?
    let orderLine: DelightTextThemeDTO?
    let headline: DelightTextThemeDTO?
    let rewardDescription: DelightTextThemeDTO?
    let ctaHelperText: DelightTextThemeDTO?
    let cta: DelightCTAThemeDTO?
    let terms: DelightTermsThemeDTO?
    let footerLinks: DelightFooterLinksThemeDTO?
    let closeButton: DelightCloseButtonThemeDTO?
    let slider: DelightSliderThemeDTO?
}

struct DelightOverlayThemeDTO: Decodable {
    let backgroundColor: String?
}

struct DelightWidgetContainerThemeDTO: Decodable {
    let backgroundColor: String?
    let borderRadius: String?
}

struct DelightWidgetContentContainerThemeDTO: Decodable {
    let padding: DelightPaddingDTO?
    let gap: String?
}

struct DelightCTAThemeDTO: Decodable {
    let show: Bool?
    let color: String?
    let backgroundColor: String?
    let borderRadius: String?
    let fontSize: String?
    let fontWeight: String?
    let lineHeight: String?
    let minHeight: String?
    let padding: DelightPaddingDTO?
    let margin: DelightSpacingDTO?
}

struct DelightTermsThemeDTO: Decodable {
    let show: Bool?
    let headerFontSize: String?
    let headerFontWeight: String?
    let headerColor: String?
    let headerMargin: DelightSpacingDTO?
}

struct DelightTextThemeDTO: Decodable {
    let show: Bool?
    let fontSize: String?
    let fontWeight: String?
    let lineHeight: String?
    let color: String?
    let margin: DelightSpacingDTO?
}

struct DelightAssetThemeDTO: Decodable {
    /// Web-style positioning (often px-less numbers in CDN JSON).
    let left: String?
    let top: String?
    let width: String?
    let show: Bool?
    let padding: DelightPaddingDTO?
    let height: String?
    let maxWidth: String?
    let maxHeight: String?
    let margin: DelightSpacingDTO?
}

struct DelightPaddingDTO: Decodable {
    let top: String?
    let right: String?
    let bottom: String?
    let left: String?
}

struct DelightSpacingDTO: Decodable {
    let top: String?
    let right: String?
    let bottom: String?
    let left: String?
}

struct DelightFooterLinksThemeDTO: Decodable {
    let show: Bool?
    let lineHeight: String?
    let margin: DelightSpacingDTO?
}

struct DelightCloseButtonThemeDTO: Decodable {
    let show: Bool?
    let top: String?
    let right: String?
    let width: String?
    let height: String?
    let borderRadius: String?
    let backgroundColor: String?
    let iconColor: String?
    let iconSize: String?
}

struct DelightSliderThemeDTO: Decodable {
    let show: Bool?
    let margin: DelightSpacingDTO?
    let dots: DelightSliderDotsThemeDTO?
    let arrows: DelightSliderArrowsThemeDTO?
}

struct DelightSliderDotsThemeDTO: Decodable {
    let gap: String?
    let size: String?
    let inactiveColor: String?
    let activeColor: String?
}

struct DelightSliderArrowsThemeDTO: Decodable {
    let size: String?
    let iconColor: String?
    let backgroundColor: String?
    let borderRadius: String?
}

extension DelightConfigDTO {
    var templateId: String { "modal_card_v1" }

    var resolvedLocaleCode: String {
        (language ?? popup?.defaultLocale ?? "en").lowercased()
    }

    var resolvedPopupLocale: DelightPopupLocaleDTO? {
        guard let popup else { return nil }
        return popup.locales?[resolvedLocaleCode]
            ?? popup.locales?["en"]
            ?? popup.locales?.values.first
    }

    var resolvedRewards: [DelightPopupRewardDTO] {
        (popup?.rewards ?? []).filter { $0.show != false }
    }

    func resolvedRewardLocale(for reward: DelightPopupRewardDTO?) -> DelightPopupRewardLocaleDTO? {
        guard let reward else { return nil }
        return reward.locales?[resolvedLocaleCode]
            ?? reward.locales?["en"]
            ?? reward.locales?.values.first
    }

    var termsHeaderFontSize: Double {
        parsePixelValue(popup?.theme?.terms?.headerFontSize) ?? 15
    }

    var showHostLogo: Bool {
        popup?.theme?.hostLogo?.show ?? true
    }

    var showRewardLogo: Bool {
        popup?.theme?.rewardLogo?.show ?? true
    }

    var contentGap: Double {
        parsePixelValue(popup?.theme?.widgetContentContainer?.gap) ?? 0
    }

    var contentPaddingTop: Double {
        parsePixelValue(popup?.theme?.widgetContentContainer?.padding?.top) ?? 0
    }

    var contentPaddingHorizontal: Double {
        parsePixelValue(popup?.theme?.widgetContentContainer?.padding?.left) ?? 0
    }

    var hostLogoHeight: Double {
        parsePixelValue(popup?.theme?.hostLogo?.height) ?? 40
    }

    var hostLogoMaxWidth: Double {
        parsePixelValue(popup?.theme?.hostLogo?.maxWidth) ?? 160
    }

    var hostLogoPaddingTop: Double {
        parsePixelValue(popup?.theme?.hostLogo?.padding?.top) ?? 12
    }

    var hostLogoMargin: DelightComponentInsets {
        parseInsets(popup?.theme?.hostLogo?.margin)
    }

    var rewardLogoHeight: Double {
        parsePixelValue(popup?.theme?.rewardLogo?.height) ?? 48
    }

    var rewardLogoMaxWidth: Double {
        parsePixelValue(popup?.theme?.rewardLogo?.maxWidth) ?? 200
    }

    var rewardLogoMargin: DelightComponentInsets {
        parseInsets(popup?.theme?.rewardLogo?.margin)
    }

    /// Inner padding inside the circular reward logo badge (`theme.rewardLogo.padding`). Absent ⇒ 0 on all sides.
    var rewardLogoPadding: DelightComponentInsets {
        guard let padding = popup?.theme?.rewardLogo?.padding else {
            return DelightComponentInsets(top: 0, right: 0, bottom: 0, left: 0)
        }
        return DelightComponentInsets(
            top: parsePixelValue(padding.top) ?? 0,
            right: parsePixelValue(padding.right) ?? 0,
            bottom: parsePixelValue(padding.bottom) ?? 0,
            left: parsePixelValue(padding.left) ?? 0
        )
    }

    var showCloseButton: Bool {
        popup?.theme?.closeButton?.show ?? true
    }

    var closeButtonTop: Double {
        parsePixelValue(popup?.theme?.closeButton?.top) ?? 12
    }

    var closeButtonTrailing: Double {
        parsePixelValue(popup?.theme?.closeButton?.right) ?? 12
    }

    var closeButtonSize: Double {
        parsePixelValue(popup?.theme?.closeButton?.width) ?? 36
    }

    var closeButtonCornerRadius: Double {
        parsePixelValue(popup?.theme?.closeButton?.borderRadius) ?? 8
    }

    var closeButtonIconSize: Double {
        parsePixelValue(popup?.theme?.closeButton?.iconSize) ?? 18
    }

    var closeButtonBackgroundColorHex: String? {
        popup?.theme?.closeButton?.backgroundColor
    }

    var closeButtonIconColorHex: String? {
        popup?.theme?.closeButton?.iconColor
    }

    var showSlider: Bool {
        popup?.theme?.slider?.show ?? true
    }

    var sliderMargin: DelightComponentInsets {
        parseInsets(popup?.theme?.slider?.margin)
    }

    var sliderDotSize: Double {
        parsePixelValue(popup?.theme?.slider?.dots?.size) ?? 6
    }

    var sliderDotGap: Double {
        parsePixelValue(popup?.theme?.slider?.dots?.gap) ?? 6
    }

    var sliderDotActiveColorHex: String? {
        popup?.theme?.slider?.dots?.activeColor
    }

    var sliderDotInactiveColorHex: String? {
        popup?.theme?.slider?.dots?.inactiveColor
    }

    var sliderArrowSize: Double {
        parsePixelValue(popup?.theme?.slider?.arrows?.size) ?? 28
    }

    var sliderArrowIconColorHex: String? {
        popup?.theme?.slider?.arrows?.iconColor
    }

    var sliderArrowBackgroundColorHex: String? {
        popup?.theme?.slider?.arrows?.backgroundColor
    }

    var sliderArrowCornerRadius: Double {
        parsePixelValue(popup?.theme?.slider?.arrows?.borderRadius) ?? (sliderArrowSize / 2)
    }

    var orderLineMargin: DelightComponentInsets {
        parseInsets(popup?.theme?.orderLine?.margin)
    }

    var headlineMargin: DelightComponentInsets {
        parseInsets(popup?.theme?.headline?.margin)
    }

    var descriptionMargin: DelightComponentInsets {
        parseInsets(popup?.theme?.rewardDescription?.margin)
    }

    var termsHeaderMargin: DelightComponentInsets {
        parseInsets(popup?.theme?.terms?.headerMargin)
    }

    var ctaHelperTextMargin: DelightComponentInsets {
        parseInsets(popup?.theme?.ctaHelperText?.margin)
    }

    var ctaButtonMargin: DelightComponentInsets {
        parseInsets(popup?.theme?.cta?.margin)
    }

    /// Inner padding for the CTA label (maps `theme.cta.padding` from config JSON).
    var ctaButtonPadding: DelightComponentInsets {
        guard let padding = popup?.theme?.cta?.padding else {
            return DelightComponentInsets(top: 12, right: 20, bottom: 12, left: 20)
        }
        return DelightComponentInsets(
            top: parsePixelValue(padding.top) ?? 0,
            right: parsePixelValue(padding.right) ?? 0,
            bottom: parsePixelValue(padding.bottom) ?? 0,
            left: parsePixelValue(padding.left) ?? 0
        )
    }

    var showFooterLinks: Bool {
        popup?.theme?.footerLinks?.show ?? true
    }

    var footerLinksMargin: DelightComponentInsets {
        parseInsets(popup?.theme?.footerLinks?.margin)
    }

    var showOrderLine: Bool {
        popup?.theme?.orderLine?.show ?? true
    }

    var showHeadline: Bool {
        popup?.theme?.headline?.show ?? true
    }

    var showDescription: Bool {
        popup?.theme?.rewardDescription?.show ?? true
    }

    var showTermsHeader: Bool {
        popup?.theme?.terms?.show ?? true
    }

    var showCtaHelperText: Bool {
        popup?.theme?.ctaHelperText?.show ?? true
    }

    var showCTAButton: Bool {
        popup?.theme?.cta?.show ?? true
    }

    var orderLineFontSize: Double {
        parsePixelValue(popup?.theme?.orderLine?.fontSize) ?? 14
    }

    var orderLineFontWeight: Double {
        parseWeightValue(popup?.theme?.orderLine?.fontWeight) ?? 600
    }

    var orderLineColorHex: String? {
        popup?.theme?.orderLine?.color
    }

    var orderLineLineHeight: Double {
        parseNumericValue(popup?.theme?.orderLine?.lineHeight) ?? 1.4
    }

    var headlineFontSize: Double {
        parsePixelValue(popup?.theme?.headline?.fontSize) ?? 24
    }

    var headlineFontWeight: Double {
        parseWeightValue(popup?.theme?.headline?.fontWeight) ?? 700
    }

    var headlineColorHex: String? {
        popup?.theme?.headline?.color
    }

    var headlineLineHeight: Double {
        parseNumericValue(popup?.theme?.headline?.lineHeight) ?? 1.25
    }

    var descriptionFontSize: Double {
        parsePixelValue(popup?.theme?.rewardDescription?.fontSize) ?? 14
    }

    var descriptionFontWeight: Double {
        parseWeightValue(popup?.theme?.rewardDescription?.fontWeight) ?? 400
    }

    var descriptionColorHex: String? {
        popup?.theme?.rewardDescription?.color
    }

    var descriptionLineHeight: Double {
        parseNumericValue(popup?.theme?.rewardDescription?.lineHeight) ?? 1.5
    }

    var ctaHelperTextFontSize: Double {
        parsePixelValue(popup?.theme?.ctaHelperText?.fontSize) ?? 12
    }

    var ctaHelperTextFontWeight: Double {
        parseWeightValue(popup?.theme?.ctaHelperText?.fontWeight) ?? 400
    }

    var ctaHelperTextColorHex: String? {
        popup?.theme?.ctaHelperText?.color
    }

    var ctaHelperTextLineHeight: Double {
        parseNumericValue(popup?.theme?.ctaHelperText?.lineHeight) ?? 1.4
    }

    var ctaButtonFontSize: Double {
        parsePixelValue(popup?.theme?.cta?.fontSize) ?? 18
    }

    var ctaButtonFontWeight: Double {
        parseWeightValue(popup?.theme?.cta?.fontWeight) ?? 700
    }

    var ctaButtonLineHeight: Double {
        parseNumericValue(popup?.theme?.cta?.lineHeight) ?? 1.2
    }

    var footerLinksLineHeight: Double {
        parseNumericValue(popup?.theme?.footerLinks?.lineHeight) ?? 1.4
    }

    var ctaButtonMinHeight: Double {
        parsePixelValue(popup?.theme?.cta?.minHeight) ?? 48
    }

    var ctaButtonCornerRadius: Double {
        parsePixelValue(popup?.theme?.cta?.borderRadius) ?? 999
    }

    private func parsePixelValue(_ value: String?) -> Double? {
        guard let value else { return nil }
        let cleaned = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "px", with: "")
        return Double(cleaned)
    }

    private func parseWeightValue(_ value: String?) -> Double? {
        guard let value else { return nil }
        return Double(value.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private func parseNumericValue(_ value: String?) -> Double? {
        parsePixelValue(value)
    }

    private func parseInsets(_ spacing: DelightSpacingDTO?) -> DelightComponentInsets {
        DelightComponentInsets(
            top: parsePixelValue(spacing?.top) ?? 0,
            right: parsePixelValue(spacing?.right) ?? 0,
            bottom: parsePixelValue(spacing?.bottom) ?? 0,
            left: parsePixelValue(spacing?.left) ?? 0
        )
    }
}

struct DelightComponentInsets {
    let top: Double
    let right: Double
    let bottom: Double
    let left: Double
}
