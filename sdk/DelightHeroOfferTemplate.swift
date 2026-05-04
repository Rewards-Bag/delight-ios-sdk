import SwiftUI
import UIKit
import SafariServices
import WebKit

struct DelightHeroOfferTemplate: View {
    let config: DelightConfigDTO
    let theme: DelightPopupTheme
    let onPrimary: (String?) -> Void
    let onDismiss: () -> Void
    @Environment(\.openURL) private var openURL
    @State private var currentRewardIndex = 0
    @State private var safariFallbackRoute: SafariFallbackRoute?

    var body: some View {
        let rewards = config.resolvedRewards
        let clampedIndex = rewards.isEmpty ? 0 : min(currentRewardIndex, rewards.count - 1)
        let reward = rewards.isEmpty ? nil : rewards[clampedIndex]
        let rewardLocale = config.resolvedRewardLocale(for: reward)
        let popupLocale = config.resolvedPopupLocale
        let orderLineFontSize = CGFloat(config.orderLineFontSize)
        let orderLineLineSpacing = lineSpacing(fontSize: orderLineFontSize, lineHeight: config.orderLineLineHeight)
        let headlineFontSize = CGFloat(config.headlineFontSize)
        let headlineWeight = fontWeight(from: config.headlineFontWeight, fallback: .bold)
        let headlineColor = colorFromHex(config.headlineColorHex, fallback: .black)
        let headlineLineSpacing = lineSpacing(fontSize: headlineFontSize, lineHeight: config.headlineLineHeight)
        let descriptionFontSize = CGFloat(config.descriptionFontSize)
        let descriptionWeight = fontWeight(from: config.descriptionFontWeight, fallback: .regular)
        let descriptionColor = colorFromHex(config.descriptionColorHex, fallback: Color.black.opacity(0.55))
        let descriptionLineSpacing = lineSpacing(fontSize: descriptionFontSize, lineHeight: config.descriptionLineHeight)
        let ctaHelperTextFontSize = CGFloat(config.ctaHelperTextFontSize)
        let ctaHelperTextWeight = fontWeight(from: config.ctaHelperTextFontWeight, fallback: .regular)
        let ctaHelperTextLineSpacing = lineSpacing(fontSize: ctaHelperTextFontSize, lineHeight: config.ctaHelperTextLineHeight)
        let ctaButtonFontSize = CGFloat(config.ctaButtonFontSize)
        let ctaButtonWeight = fontWeight(from: config.ctaButtonFontWeight, fallback: .bold)
        let ctaButtonLineSpacing = lineSpacing(fontSize: ctaButtonFontSize, lineHeight: config.ctaButtonLineHeight)
        let ctaButtonMinHeight = CGFloat(config.ctaButtonMinHeight)
        let footerLinksLineSpacing = lineSpacing(fontSize: 10, lineHeight: config.footerLinksLineHeight)
        let contentGap = CGFloat(config.contentGap)
        let contentPaddingTop = CGFloat(config.contentPaddingTop)
        let contentPaddingHorizontal = CGFloat(config.contentPaddingHorizontal)
        let closeButtonSize = CGFloat(config.closeButtonSize)
        let closeButtonIconSize = CGFloat(config.closeButtonIconSize)
        let closeButtonCornerRadius = CGFloat(config.closeButtonCornerRadius)
        let closeButtonTop = CGFloat(config.closeButtonTop)
        let closeButtonTrailing = CGFloat(config.closeButtonTrailing)
        let closeButtonBG = colorFromCss(config.closeButtonBackgroundColorHex, fallback: .white)
        let closeButtonIconColor = colorFromCss(config.closeButtonIconColorHex, fallback: .black)
        let sliderDotSize = CGFloat(config.sliderDotSize)
        let sliderDotGap = CGFloat(config.sliderDotGap)
        let sliderDotActive = colorFromCss(config.sliderDotActiveColorHex, fallback: Color.black.opacity(0.8))
        let sliderDotInactive = colorFromCss(config.sliderDotInactiveColorHex, fallback: Color.gray.opacity(0.35))
        let sliderArrowSize = CGFloat(config.sliderArrowSize)
        let sliderArrowBG = colorFromCss(config.sliderArrowBackgroundColorHex, fallback: Color.black.opacity(0.06))
        let sliderArrowIcon = colorFromCss(config.sliderArrowIconColorHex, fallback: .black)
        let sliderArrowCornerRadius = CGFloat(config.sliderArrowCornerRadius)
        let sliderMargin = edgeInsets(from: config.sliderMargin)
        let orderLineMargin = edgeInsets(from: config.orderLineMargin)
        let headlineMargin = edgeInsets(from: config.headlineMargin)
        let descriptionMargin = edgeInsets(from: config.descriptionMargin)
        let ctaHelperTextMargin = edgeInsets(from: config.ctaHelperTextMargin)
        let ctaButtonMargin = edgeInsets(from: config.ctaButtonMargin)
        let ctaButtonInnerPadding = edgeInsets(from: config.ctaButtonPadding)
        let footerLinksMargin = edgeInsets(from: config.footerLinksMargin)
        let rewardLogoBadgeOuterInsets = edgeInsets(from: DelightRewardLogoMetrics.outerInsets(for: config))
        let rewardLogoInnerPadding = edgeInsets(from: config.rewardLogoPadding)

        let heroBannerHeight: CGFloat = 208
        let rewardBadgeDiameter: CGFloat = DelightRewardLogoMetrics.badgeDiameter(for: config)
        /// Same leading/trailing inset for the widget body column (aligns badge with text edge).
        let widgetBodyLeadingInset: CGFloat = 8
        /// Nest these so inset-from-card-edge matches the pre–column-padding layout (16 / 20 / 12).
        let descriptionRelativeHorizontalInset = max(0, 16 - widgetBodyLeadingInset)
        let finePrintRelativeHorizontalInset = max(0, 20 - widgetBodyLeadingInset)
        let redemptionRelativeHorizontalInset = max(0, 12 - widgetBodyLeadingInset)
        let rewardLogoOverlayPadding = EdgeInsets(
            top: rewardLogoBadgeOuterInsets.top,
            leading: widgetBodyLeadingInset,
            bottom: rewardLogoBadgeOuterInsets.bottom,
            trailing: rewardLogoBadgeOuterInsets.trailing
        )
        /// Half the badge sits in the hero, half in the body: top edge = seam − diameter/2 (minus configured top inset).
        let rewardLogoBadgeOffsetY = heroBannerHeight - (rewardBadgeDiameter / 2) - rewardLogoOverlayPadding.top

        ZStack(alignment: .topLeading) {
            theme.overlay
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea()

            ZStack(alignment: .topLeading) {
                VStack(spacing: 0) {
                    ZStack(alignment: .topTrailing) {
                        heroBanner(reward: reward, height: heroBannerHeight)

                        if config.showCloseButton {
                            Button {
                                onDismiss()
                            } label: {
                                Image(systemName: "minus")
                                    .font(.system(size: closeButtonIconSize, weight: .bold))
                                    .foregroundStyle(closeButtonIconColor)
                                    .frame(width: closeButtonSize, height: closeButtonSize)
                                    .background(closeButtonBG)
                                    .clipShape(RoundedRectangle(cornerRadius: closeButtonCornerRadius))
                            }
                            .padding(.top, closeButtonTop)
                            .padding(.trailing, closeButtonTrailing)
                        }
                    }

                    VStack(spacing: contentGap) {
                        if config.showSlider, rewards.count > 1 {
                            rewardSliderControls(
                                rewardCount: rewards.count,
                                selectedIndex: clampedIndex,
                                dotSize: sliderDotSize,
                                dotGap: sliderDotGap,
                                activeDotColor: sliderDotActive,
                                inactiveDotColor: sliderDotInactive,
                                arrowSize: sliderArrowSize,
                                arrowBackgroundColor: sliderArrowBG,
                                arrowIconColor: sliderArrowIcon,
                                arrowCornerRadius: sliderArrowCornerRadius
                            )
                            .padding(sliderMargin)
                        }

                        if config.showOrderLine, let subtitle = popupLocale?.orderLine {
                            Text(subtitle.uppercased())
                                .font(.system(size: max(11, orderLineFontSize - 2), weight: .semibold))
                                .tracking(0.6)
                                .foregroundStyle(supportingTextColor)
                                .lineSpacing(orderLineLineSpacing)
                                .multilineTextAlignment(.center)
                                .padding(orderLineMargin)
                        }

                        if config.showHeadline {
                            Text(rewardLocale?.headline ?? "Thanks for your order")
                                .font(.system(size: headlineFontSize, weight: headlineWeight))
                                .multilineTextAlignment(.center)
                                .foregroundStyle(headlineColor)
                                .lineSpacing(headlineLineSpacing)
                                .scaleEffect(theme.fontScale)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(headlineMargin)
                        }

                        if config.showDescription,
                           let description = rewardLocale?.description?.htmlToPlainText(),
                           !description.isEmpty {
                            Text(description)
                                .font(.system(size: descriptionFontSize, weight: descriptionWeight))
                                .multilineTextAlignment(.center)
                                .foregroundStyle(descriptionColor.opacity(0.85))
                                .lineSpacing(descriptionLineSpacing)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.horizontal, descriptionRelativeHorizontalInset)
                                .padding(descriptionMargin)
                        }

                        if let finePrint = compactTermsDisclaimer(rewardLocale?.terms),
                           !finePrint.isEmpty {
                            Text(finePrint)
                                .font(.system(size: max(11, descriptionFontSize - 3), weight: .regular))
                                .foregroundStyle(supportingTextColor)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, finePrintRelativeHorizontalInset)
                                .padding(.top, -contentGap * 0.35)
                        }

                        Color.clear.frame(height: max(4, contentGap))

                        if config.showCTAButton {
                            HStack(spacing: 0) {
                                Button {
                                    openCTAUrl(reward?.ctaUrl) {
                                        onPrimary(reward?.id)
                                    }
                                } label: {
                                    Text(rewardLocale?.cta ?? popupLocale?.cta ?? "Claim now")
                                        .font(.system(size: ctaButtonFontSize, weight: ctaButtonWeight))
                                        .lineSpacing(ctaButtonLineSpacing)
                                        .multilineTextAlignment(.center)
                                        .foregroundStyle(theme.onPrimary)
                                        .frame(maxWidth: .infinity)
                                        .padding(ctaButtonInnerPadding)
                                        .frame(minHeight: CGFloat(ctaButtonMinHeight))
                                        .background(theme.primary)
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                                .shadow(color: Color.black.opacity(0.12), radius: 8, y: 4)
                            }
                            .padding(.horizontal, finePrintRelativeHorizontalInset)
                            .padding(ctaButtonMargin)
                        }

                        if config.showCtaHelperText {
                            redemptionNote(
                                rewardLocale: rewardLocale,
                                fontSize: ctaHelperTextFontSize,
                                fontWeight: ctaHelperTextWeight,
                                lineSpacing: ctaHelperTextLineSpacing,
                                horizontalPadding: redemptionRelativeHorizontalInset,
                                margin: ctaHelperTextMargin
                            )
                        }

                        if config.showFooterLinks {
                            screenshotStyleFooterLinks(
                                reward: reward,
                                popupLocale: popupLocale,
                                lineSpacing: footerLinksLineSpacing,
                                margin: footerLinksMargin
                            )
                        }
                    }
                    .padding(.top, 4 + CGFloat(contentPaddingTop))
                    .padding(.horizontal, widgetBodyLeadingInset)
                    .padding(.bottom, 8)
                    .background(Color.white)
                }
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: theme.radius))
                .overlay(
                    RoundedRectangle(cornerRadius: theme.radius)
                        .stroke(Color.black.opacity(0.08), lineWidth: 1)
                )
                .overlay(alignment: .topLeading) {
                    if config.showRewardLogo,
                       let rewardLogoUrl = reward?.logo,
                       let rewardLogoURL = URL(string: rewardLogoUrl) {
                        rewardBadge(url: rewardLogoURL, diameter: rewardBadgeDiameter, contentPadding: rewardLogoInnerPadding)
                            .shadow(color: Color.black.opacity(0.14), radius: 8, y: 3)
                            .padding(rewardLogoOverlayPadding)
                            .offset(y: rewardLogoBadgeOffsetY)
                    } else if config.showRewardLogo {
                        placeholderSlot(label: "Reward", height: max(44, rewardBadgeDiameter - 14))
                            .frame(width: rewardBadgeDiameter, height: rewardBadgeDiameter)
                            .clipShape(Circle())
                            .padding(rewardLogoOverlayPadding)
                            .offset(y: rewardLogoBadgeOffsetY)
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 8)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .ignoresSafeArea(edges: .bottom)
        .presentationDetents([.large])
        .sheet(item: $safariFallbackRoute) { route in
            SafariFallbackView(url: route.url)
        }
    }

    @ViewBuilder
    private func heroBanner(reward: DelightPopupRewardDTO?, height: CGFloat) -> some View {
        Group {
            if let imageUrl = reward?.postPopupMobileImage ?? reward?.postPopupWebImage,
               let imageURL = URL(string: imageUrl) {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        imagePlaceholder
                    }
                }
            } else {
                imagePlaceholder
            }
        }
        .frame(height: height)
        .frame(maxWidth: .infinity)
        .clipped()
    }

    @ViewBuilder
    private func rewardBadge(url: URL, diameter: CGFloat, contentPadding: EdgeInsets) -> some View {
        ZStack {
            Circle()
                .fill(Color.white)
            logoImage(url: url, height: diameter, maxWidth: diameter)
                .padding(contentPadding)
                .frame(width: diameter, height: diameter)
                .clipShape(Circle())
        }
        .frame(width: diameter, height: diameter)
        .overlay(
            Circle()
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        )
    }

    private func compactTermsDisclaimer(_ termsHtml: String?) -> String? {
        let plain = termsHtml?
            .htmlToPlainText()
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !plain.isEmpty else { return nil }
        if plain.count <= 140 { return plain }
        if let range = plain.range(of: ". ") {
            return String(plain[..<range.upperBound]).trimmingCharacters(in: .whitespaces)
        }
        return String(plain.prefix(136)).trimmingCharacters(in: .whitespacesAndNewlines) + "…"
    }

    /// Older SDK snapshots may omit these fields on decodable DTOs; use reflection so the template still compiles everywhere.
    private func redemptionBodyLine(_ rewardLocale: DelightPopupRewardLocaleDTO?) -> String? {
        mirrorOptionalString(label: "emailDisclaimer", in: rewardLocale)
            ?? rewardLocale?.ctaHelperText
    }

    private func partnerTermsLinkLabel(_ popupLocale: DelightPopupLocaleDTO?) -> String {
        mirrorOptionalString(label: "partnerTerms", in: popupLocale)
            ?? "Partner Terms & Conditions"
    }

    private func mirrorOptionalString(label: String, in value: Any?) -> String? {
        guard let value else { return nil }
        let mirror = Mirror(reflecting: value)
        for child in mirror.children where child.label == label {
            return mirrorUnwrapOptionalString(child.value)
        }
        return nil
    }

    private func mirrorUnwrapOptionalString(_ any: Any) -> String? {
        if let direct = any as? String {
            return direct
        }
        let mirror = Mirror(reflecting: any)
        guard mirror.displayStyle == .optional else {
            return any as? String
        }
        for child in mirror.children {
            if let s = child.value as? String {
                return s
            }
        }
        return nil
    }

    @ViewBuilder
    private func redemptionNote(
        rewardLocale: DelightPopupRewardLocaleDTO?,
        fontSize: CGFloat,
        fontWeight: Font.Weight,
        lineSpacing: CGFloat,
        horizontalPadding: CGFloat,
        margin: EdgeInsets
    ) -> some View {
        let raw = redemptionBodyLine(rewardLocale)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        Group {
            if let raw, !raw.isEmpty {
                Text(raw)
                    .font(.system(size: max(11, fontSize), weight: fontWeight))
                    .foregroundStyle(supportingTextColor)
                    .multilineTextAlignment(.center)
                    .lineSpacing(lineSpacing)
                    .padding(.horizontal, horizontalPadding)
                    .padding(margin)
            }
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func screenshotStyleFooterLinks(
        reward: DelightPopupRewardDTO?,
        popupLocale: DelightPopupLocaleDTO?,
        lineSpacing: CGFloat,
        margin: EdgeInsets
    ) -> some View {
        let partnerTermsLabel = partnerTermsLinkLabel(popupLocale)
        let poweredByLabel = popupLocale?.poweredBy ?? "Powered by RewardsBag"
        let privacyLabel = popupLocale?.privacyPolicy ?? "Privacy Policy"
        HStack(spacing: 6) {
            footerLink(title: partnerTermsLabel, rawUrl: mirrorOptionalString(label: "partnerTermsUrl", in: reward))
            Text("|")
                .foregroundStyle(supportingTextColor)
                .accessibilityHidden(true)
            footerLink(title: poweredByLabel, rawUrl: mirrorOptionalString(label: "poweredByUrl", in: reward))
            Text("|")
                .foregroundStyle(supportingTextColor)
                .accessibilityHidden(true)
            footerLink(title: privacyLabel, rawUrl: mirrorOptionalString(label: "privacyPolicyUrl", in: reward))
        }
        .font(.system(size: 9, weight: .medium))
        .foregroundStyle(supportingTextColor)
        .lineSpacing(lineSpacing)
        .lineLimit(1)
        .minimumScaleFactor(0.65)
        .allowsTightening(true)
        .frame(maxWidth: .infinity)
        .padding(margin)
    }

    private func footerLink(title: String, rawUrl: String?) -> some View {
        Button {
            guard let url = resolvedCTAUrl(from: rawUrl) else { return }
            openRewardURL(url)
        } label: {
            Text(title)
                .underline()
        }
        .buttonStyle(.plain)
        .disabled(resolvedCTAUrl(from: rawUrl) == nil)
        .opacity(resolvedCTAUrl(from: rawUrl) == nil ? 0.6 : 1)
    }

    private func openRewardURL(_ url: URL) {
        openURL(url) { accepted in
            if accepted {
                return
            }
            UIApplication.shared.open(url, options: [:]) { opened in
                if !opened {
                    safariFallbackRoute = SafariFallbackRoute(url: url)
                }
            }
        }
    }

    private func logoImage(url: URL, height: CGFloat, maxWidth: CGFloat) -> some View {
        Group {
            if url.pathExtension.lowercased() == "svg" {
                SVGRemoteImageView(url: url)
            } else {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                    default:
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.08))
                            .overlay(
                                ProgressView()
                            )
                    }
                }
            }
        }
        .frame(maxWidth: maxWidth, maxHeight: height)
    }

    private var imagePlaceholder: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [Color.gray.opacity(0.22), Color.gray.opacity(0.08)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                Image(systemName: "person.crop.rectangle")
                    .font(.system(size: 60, weight: .light))
                    .foregroundStyle(Color.black.opacity(0.5))
            )
    }

    private var supportingTextColor: Color {
        Color.black.opacity(0.56)
    }

    private func placeholderSlot(label: String, height: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.gray.opacity(0.06))
                .frame(height: height)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                        .foregroundStyle(Color.gray.opacity(0.4))
                )

            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.gray)
        }
    }

    private func rewardSliderControls(
        rewardCount: Int,
        selectedIndex: Int,
        dotSize: CGFloat,
        dotGap: CGFloat,
        activeDotColor: Color,
        inactiveDotColor: Color,
        arrowSize: CGFloat,
        arrowBackgroundColor: Color,
        arrowIconColor: Color,
        arrowCornerRadius: CGFloat
    ) -> some View {
        HStack(spacing: 12) {
            Button {
                guard rewardCount > 0 else { return }
                currentRewardIndex = (selectedIndex - 1 + rewardCount) % rewardCount
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(arrowIconColor)
                    .frame(width: arrowSize, height: arrowSize)
                    .background(arrowBackgroundColor)
                    .clipShape(RoundedRectangle(cornerRadius: arrowCornerRadius))
            }

            HStack(spacing: dotGap) {
                ForEach(0..<rewardCount, id: \.self) { index in
                    Circle()
                        .fill(index == selectedIndex ? activeDotColor : inactiveDotColor)
                        .frame(width: dotSize, height: dotSize)
                }
            }

            Button {
                guard rewardCount > 0 else { return }
                currentRewardIndex = (selectedIndex + 1) % rewardCount
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(arrowIconColor)
                    .frame(width: arrowSize, height: arrowSize)
                    .background(arrowBackgroundColor)
                    .clipShape(RoundedRectangle(cornerRadius: arrowCornerRadius))
            }
        }
    }

    private func fontWeight(from rawValue: Double, fallback: Font.Weight) -> Font.Weight {
        switch rawValue {
        case ..<350: return .light
        case ..<450: return .regular
        case ..<550: return .medium
        case ..<650: return .semibold
        case ..<750: return .bold
        default: return .heavy
        }
    }

    private func fontWeight(from rawValue: String?, fallback: Font.Weight) -> Font.Weight {
        guard let rawValue, let numeric = Double(rawValue) else { return fallback }
        return fontWeight(from: numeric, fallback: fallback)
    }

    private func colorFromHex(_ hex: String?, fallback: Color) -> Color {
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

    private func colorFromCss(_ css: String?, fallback: Color) -> Color {
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
                return Color(red: red / 255.0, green: green / 255.0, blue: blue / 255.0, opacity: alpha)
            }
        }
        return fallback
    }

    private func edgeInsets(from insets: DelightComponentInsets) -> EdgeInsets {
        EdgeInsets(
            top: CGFloat(insets.top),
            leading: CGFloat(insets.left),
            bottom: CGFloat(insets.bottom),
            trailing: CGFloat(insets.right)
        )
    }

    private func lineSpacing(fontSize: CGFloat, lineHeight: Double) -> CGFloat {
        max(0, (CGFloat(lineHeight) * fontSize) - fontSize)
    }

    private func openCTAUrl(_ rawUrl: String?, completion: @escaping () -> Void) {
        guard let url = resolvedCTAUrl(from: rawUrl) else {
            completion()
            return
        }

        openURL(url) { accepted in
            if accepted {
                completion()
                return
            }

            UIApplication.shared.open(url, options: [:]) { opened in
                if !opened {
                    safariFallbackRoute = SafariFallbackRoute(url: url)
                }
                completion()
            }
        }
    }

    private func resolvedCTAUrl(from rawUrl: String?) -> URL? {
        guard let rawUrl else { return nil }
        let trimmed = rawUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let url = URL(string: trimmed), url.scheme != nil {
            return url
        }

        if let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed),
           let encodedUrl = URL(string: encoded),
           encodedUrl.scheme != nil {
            return encodedUrl
        }

        return nil
    }
}

private struct SafariFallbackRoute: Identifiable {
    let id = UUID()
    let url: URL
}

private struct SafariFallbackView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

private struct SVGRemoteImageView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView(frame: .zero)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        webView.isUserInteractionEnabled = false
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        let html = """
        <html>
          <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <style>
              html, body {
                margin: 0;
                padding: 0;
                width: 100%;
                height: 100%;
                background: transparent;
                overflow: hidden;
              }
              img {
                width: 100%;
                height: 100%;
                object-fit: contain;
              }
            </style>
          </head>
          <body>
            <img src="\(url.absoluteString)" />
          </body>
        </html>
        """
        webView.loadHTMLString(html, baseURL: nil)
    }
}

private extension String {
    func htmlToPlainText() -> String {
        replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
