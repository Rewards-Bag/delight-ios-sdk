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
        let termsHeaderFontSize = CGFloat(config.termsHeaderFontSize)
        let subtitleFontSize = CGFloat(config.orderLineFontSize)
        let subtitleWeight = fontWeight(from: config.orderLineFontWeight, fallback: .semibold)
        let subtitleColor = colorFromHex(config.orderLineColorHex, fallback: Color.black.opacity(0.7))
        let subtitleLineSpacing = lineSpacing(fontSize: subtitleFontSize, lineHeight: config.orderLineLineHeight)
        let headlineFontSize = CGFloat(config.headlineFontSize)
        let headlineWeight = fontWeight(from: config.headlineFontWeight, fallback: .bold)
        let headlineColor = colorFromHex(config.headlineColorHex, fallback: .black)
        let headlineLineSpacing = lineSpacing(fontSize: headlineFontSize, lineHeight: config.headlineLineHeight)
        let descriptionFontSize = CGFloat(config.descriptionFontSize)
        let descriptionWeight = fontWeight(from: config.descriptionFontWeight, fallback: .regular)
        let descriptionColor = colorFromHex(config.descriptionColorHex, fallback: Color.black.opacity(0.55))
        let descriptionLineSpacing = lineSpacing(fontSize: descriptionFontSize, lineHeight: config.descriptionLineHeight)
        let termsHeaderWeight = fontWeight(from: config.popup?.theme?.terms?.headerFontWeight, fallback: .semibold)
        let termsHeaderColor = colorFromHex(config.popup?.theme?.terms?.headerColor, fallback: Color.black.opacity(0.75))
        let ctaHelperTextFontSize = CGFloat(config.ctaHelperTextFontSize)
        let ctaHelperTextWeight = fontWeight(from: config.ctaHelperTextFontWeight, fallback: .regular)
        let ctaHelperTextColor = colorFromHex(config.ctaHelperTextColorHex, fallback: Color.black.opacity(0.6))
        let ctaHelperTextLineSpacing = lineSpacing(fontSize: ctaHelperTextFontSize, lineHeight: config.ctaHelperTextLineHeight)
        let ctaButtonFontSize = CGFloat(config.ctaButtonFontSize)
        let ctaButtonWeight = fontWeight(from: config.ctaButtonFontWeight, fallback: .bold)
        let ctaButtonLineSpacing = lineSpacing(fontSize: ctaButtonFontSize, lineHeight: config.ctaButtonLineHeight)
        let ctaButtonMinHeight = CGFloat(config.ctaButtonMinHeight)
        let ctaButtonCornerRadius = CGFloat(config.ctaButtonCornerRadius)
        let footerLinksLineSpacing = lineSpacing(fontSize: 10, lineHeight: config.footerLinksLineHeight)
        let contentGap = CGFloat(config.contentGap)
        let contentPaddingTop = CGFloat(config.contentPaddingTop)
        let contentPaddingHorizontal = CGFloat(config.contentPaddingHorizontal)
        let hostLogoHeight = CGFloat(config.hostLogoHeight)
        let hostLogoMaxWidth = CGFloat(config.hostLogoMaxWidth)
        let hostLogoPaddingTop = CGFloat(config.hostLogoPaddingTop)
        let rewardLogoHeight = CGFloat(config.rewardLogoHeight)
        let rewardLogoMaxWidth = CGFloat(config.rewardLogoMaxWidth)
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
        let hostLogoMargin = edgeInsets(from: config.hostLogoMargin)
        let rewardLogoMargin = edgeInsets(from: config.rewardLogoMargin)
        let sliderMargin = edgeInsets(from: config.sliderMargin)
        let orderLineMargin = edgeInsets(from: config.orderLineMargin)
        let headlineMargin = edgeInsets(from: config.headlineMargin)
        let descriptionMargin = edgeInsets(from: config.descriptionMargin)
        let termsHeaderMargin = edgeInsets(from: config.termsHeaderMargin)
        let ctaHelperTextMargin = edgeInsets(from: config.ctaHelperTextMargin)
        let ctaButtonMargin = edgeInsets(from: config.ctaButtonMargin)
        let footerLinksMargin = edgeInsets(from: config.footerLinksMargin)

        ZStack(alignment: .topLeading) {
            theme.overlay
                .ignoresSafeArea()

            ZStack(alignment: .topLeading) {
                VStack(spacing: 0) {
                    ZStack {
                        if let imageUrl = reward?.postPopupMobileImage ?? reward?.postPopupWebImage, let imageURL = URL(string: imageUrl) {
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
                    .frame(height: 200)
                    .clipped()

                    VStack(spacing: contentGap) {
                        if config.showHostLogo,
                           let hostLogoUrl = config.partnerLogo,
                           let hostLogoURL = URL(string: hostLogoUrl) {
                            logoImage(url: hostLogoURL, height: hostLogoHeight, maxWidth: hostLogoMaxWidth)
                                .padding(.top, hostLogoPaddingTop)
                                .padding(hostLogoMargin)
                        } else if config.showHostLogo {
                            hostLogoImage()
                                .padding(.top, hostLogoPaddingTop)
                                .padding(hostLogoMargin)
                        }

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
                            Text(subtitle)
                                .font(.system(size: subtitleFontSize, weight: subtitleWeight))
                                .foregroundStyle(subtitleColor)
                                .lineSpacing(subtitleLineSpacing)
                                .padding(orderLineMargin)
                        }

                        if config.showHeadline {
                            Text(rewardLocale?.headline ?? "Thanks for your order")
                                .font(.system(size: headlineFontSize, weight: headlineWeight))
                                .multilineTextAlignment(.center)
                                .foregroundStyle(headlineColor)
                                .lineSpacing(headlineLineSpacing)
                                .scaleEffect(theme.fontScale)
                                .padding(headlineMargin)
                        }

                        if config.showDescription,
                           let description = rewardLocale?.description?.htmlToPlainText(),
                           !description.isEmpty {
                            Text(description)
                                .font(.system(size: descriptionFontSize, weight: descriptionWeight))
                                .multilineTextAlignment(.center)
                                .foregroundStyle(descriptionColor)
                                .lineSpacing(descriptionLineSpacing)
                                .padding(.horizontal, 20)
                                .padding(descriptionMargin)
                        }

                        if config.showRewardLogo,
                           let rewardLogoUrl = reward?.logo,
                           let rewardLogoURL = URL(string: rewardLogoUrl) {
                            logoImage(url: rewardLogoURL, height: rewardLogoHeight, maxWidth: rewardLogoMaxWidth)
                                .padding(.horizontal, 20)
                                .padding(rewardLogoMargin)
                        } else if config.showRewardLogo {
                            placeholderSlot(label: "Reward logo placeholder", height: 34)
                                .padding(.horizontal, 20)
                                .padding(rewardLogoMargin)
                        }

                        if config.showTermsHeader {
                            HStack(spacing: 6) {
                                Text(popupLocale?.terms?.header ?? "Terms & Conditions")
                                    .font(.system(size: termsHeaderFontSize, weight: termsHeaderWeight))
                                    .foregroundStyle(termsHeaderColor)
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(Color.black.opacity(0.65))
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 20)
                            .padding(termsHeaderMargin)
                        }

                        if config.showCtaHelperText,
                           let ctaHelperText = rewardLocale?.ctaHelperText,
                           !ctaHelperText.isEmpty {
                            Text(ctaHelperText)
                                .font(.system(size: ctaHelperTextFontSize, weight: ctaHelperTextWeight))
                                .multilineTextAlignment(.center)
                                .foregroundStyle(ctaHelperTextColor)
                                .lineSpacing(ctaHelperTextLineSpacing)
                                .lineLimit(2)
                                .padding(.horizontal, 20)
                                .padding(ctaHelperTextMargin)
                        } else if config.showCtaHelperText {
                            placeholderSlot(label: "Small CTA text placeholder", height: 24)
                                .padding(.horizontal, 20)
                                .padding(ctaHelperTextMargin)
                        }

                        if config.showCTAButton {
                            Button(rewardLocale?.cta ?? popupLocale?.cta ?? "Claim now") {
                                openCTAUrl(reward?.ctaUrl) {
                                    onPrimary(reward?.id)
                                }
                            }
                            .font(.system(size: ctaButtonFontSize, weight: ctaButtonWeight))
                            .lineSpacing(ctaButtonLineSpacing)
                            .foregroundStyle(theme.onPrimary)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: ctaButtonMinHeight)
                            .padding(.vertical, 14)
                            .background(theme.primary)
                            .clipShape(RoundedRectangle(cornerRadius: ctaButtonCornerRadius))
                            .padding(.horizontal, 22)
                            .padding(ctaButtonMargin)
                        }

                        if config.showFooterLinks {
                            HStack(spacing: 8) {
                                Button(popupLocale?.poweredBy ?? "Powered by RewardsBag") {}
                                Text("|")
                                Button(popupLocale?.privacyPolicy ?? "Privacy Policy") {}
                            }
                            .font(.system(size: 10))
                            .foregroundStyle(.gray)
                            .lineSpacing(footerLinksLineSpacing)
                            .padding(.top, 2)
                            .padding(.bottom, 10)
                            .padding(footerLinksMargin)
                        }
                    }
                    .padding(.top, contentPaddingTop)
                    .padding(.horizontal, contentPaddingHorizontal)
                    .background(Color.white)
                }
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: theme.radius))
                .overlay(
                    RoundedRectangle(cornerRadius: theme.radius)
                        .stroke(Color.black.opacity(0.08), lineWidth: 1)
                )
                .overlay(alignment: .topTrailing) {
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
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .ignoresSafeArea(edges: .bottom)
        .presentationDetents([.large])
        .sheet(item: $safariFallbackRoute) { route in
            SafariFallbackView(url: route.url)
        }
    }

    private func hostLogoImage() -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white)
                .frame(width: 168, height: 40)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.gray.opacity(0.25), lineWidth: 1)
                )

            HStack(spacing: 6) {
                Image(systemName: "circlebadge.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(Color.blue)
                Text("Stagecoach")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(Color.black.opacity(0.85))
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
