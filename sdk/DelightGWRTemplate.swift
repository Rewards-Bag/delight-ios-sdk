import SwiftUI
import UIKit
import SafariServices
import WebKit

struct DelightGWRTemplate: View {
    let config: DelightConfigDTO
    let theme: DelightPopupTheme
    var closeButtonAction: DelightPopupCloseButtonAction = .minimize
    let onMinimize: () -> Void
    let onPrimary: (String?) -> Void
    let onDismiss: () -> Void
    @Binding var currentRewardIndex: Int
    @Binding var claimedRewardIds: Set<String>
    @Environment(\.openURL) private var openURL
    @State private var safariFallbackRoute: SafariFallbackRoute?

    var body: some View {
        let rewards = config.resolvedRewards
        let clampedIndex = rewards.isEmpty ? 0 : min(currentRewardIndex, rewards.count - 1)
        let reward = rewards.isEmpty ? nil : rewards[clampedIndex]
        let rewardLocale = config.resolvedRewardLocale(for: reward)
        let popupLocale = config.resolvedPopupLocale
        let orderLineFontSize = CGFloat(config.orderLineFontSize)
        let headlineFontSize = CGFloat(config.headlineFontSize)
        let headlineWeight = fontWeight(from: config.headlineFontWeight, fallback: .heavy)
        let headlineColor = colorFromHex(config.headlineColorHex, fallback: .black)
        let headlineLineSpacing = lineSpacing(fontSize: headlineFontSize, lineHeight: config.headlineLineHeight)
        let descriptionFontSize = CGFloat(config.descriptionFontSize)
        let descriptionWeight = fontWeight(from: config.descriptionFontWeight, fallback: .semibold)
        let descriptionColor = colorFromHex(config.descriptionColorHex, fallback: Color.black.opacity(0.85))
        let descriptionLineSpacing = lineSpacing(fontSize: descriptionFontSize, lineHeight: config.descriptionLineHeight)
        let ctaButtonFontSize = CGFloat(config.ctaButtonFontSize)
        let ctaButtonWeight = fontWeight(from: config.ctaButtonFontWeight, fallback: .heavy)
        let ctaButtonLineSpacing = lineSpacing(fontSize: ctaButtonFontSize, lineHeight: config.ctaButtonLineHeight)
        let ctaButtonMinHeight = CGFloat(config.ctaButtonMinHeight)
        let ctaButtonCornerRadius = CGFloat(config.ctaButtonCornerRadius)
        let footerLinksLineSpacing = lineSpacing(fontSize: 11, lineHeight: config.footerLinksLineHeight)
        let closeButtonSize = min(CGFloat(config.closeButtonSize), 28)
        let closeButtonIconSize = min(CGFloat(config.closeButtonIconSize), 14)
        let closeButtonCornerRadius = CGFloat(config.closeButtonCornerRadius)
        let closeButtonBG = colorFromCss(config.closeButtonBackgroundColorHex, fallback: .white)
        let closeButtonIconColor = colorFromCss(config.closeButtonIconColorHex, fallback: Color.black.opacity(0.7))
        let sliderDotActive = colorFromCss(config.sliderDotActiveColorHex, fallback: theme.primary)
        let sliderDotInactive = colorFromCss(config.sliderDotInactiveColorHex, fallback: Color(white: 0.82))
        let sliderArrowIcon = colorFromCss(config.sliderArrowIconColorHex, fallback: theme.primary)
        let widgetImageObjectFit = config.widgetImageObjectFit
        let heroBannerHeight: CGFloat = min(200, max(160, CGFloat(config.widgetImageHeight)))

        ZStack {
            theme.overlay
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                headerBar(
                    orderLine: popupLocale?.orderLine,
                    fontSize: orderLineFontSize,
                    closeButtonSize: closeButtonSize,
                    closeButtonIconSize: closeButtonIconSize,
                    closeButtonCornerRadius: closeButtonCornerRadius,
                    closeButtonBG: closeButtonBG,
                    closeButtonIconColor: closeButtonIconColor
                )

                VStack(spacing: 12) {
                    heroBanner(
                        reward: reward,
                        height: heroBannerHeight,
                        objectFit: widgetImageObjectFit
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                    if config.showSlider, rewards.count > 1 {
                        numberedSliderControls(
                            rewardCount: rewards.count,
                            selectedIndex: clampedIndex,
                            activeColor: sliderDotActive,
                            inactiveColor: sliderDotInactive,
                            arrowColor: sliderArrowIcon
                        )
                        .padding(.top, 2)
                    }

                    if config.showHeadline {
                        Text(rewardLocale?.headline ?? "Thanks for your order")
                            .font(.system(size: min(headlineFontSize, 26), weight: headlineWeight))
                            .multilineTextAlignment(.center)
                            .foregroundColor(headlineColor)
                            .lineSpacing(headlineLineSpacing)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 16)
                    }

                    if config.showDescription,
                       let description = rewardLocale?.description?.htmlToPlainText(),
                       !description.isEmpty {
                        Text(description)
                            .font(.system(size: descriptionFontSize, weight: descriptionWeight))
                            .multilineTextAlignment(.center)
                            .foregroundColor(descriptionColor)
                            .lineSpacing(descriptionLineSpacing)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 16)
                    }

                    if config.showCTAButton {
                        Button {
                            let claimedIndex = clampedIndex
                            let claimKey = rewardClaimKey(reward, index: claimedIndex)
                            openCTAUrl(reward?.ctaUrl) {
                                claimedRewardIds.insert(claimKey)
                                onPrimary(reward?.id)
                                if let nextIndex = nextUnclaimedIndex(
                                    after: claimedIndex,
                                    rewards: rewards,
                                    claimed: claimedRewardIds.union([claimKey])
                                ) {
                                    currentRewardIndex = nextIndex
                                } else {
                                    onDismiss()
                                }
                            }
                        } label: {
                            Text(rewardLocale?.cta ?? popupLocale?.cta ?? "Claim now")
                                .font(.system(size: ctaButtonFontSize, weight: ctaButtonWeight))
                                .lineSpacing(ctaButtonLineSpacing)
                                .multilineTextAlignment(.center)
                                .foregroundColor(theme.onPrimary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .padding(.horizontal, 16)
                                .frame(minHeight: ctaButtonMinHeight)
                                .background(theme.primary)
                                .clipShape(RoundedRectangle(cornerRadius: max(12, ctaButtonCornerRadius)))
                        }
                        .buttonStyle(PlainButtonStyle())
                        .padding(.horizontal, 16)
                    }

                    VStack(spacing: 8) {
                        if let terms = termsDisclaimer(rewardLocale?.terms), !terms.isEmpty {
                            Text(terms)
                                .font(.system(size: 12, weight: .regular))
                                .foregroundColor(supportingTextColor)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                        }

                        if config.showFooterLinks {
                            footerLinks(
                                reward: reward,
                                popupLocale: popupLocale,
                                lineSpacing: footerLinksLineSpacing
                            )
                        }
                    }
                }
                .padding(.bottom, bodyColumnBottomPadding())
                .background(Color.white)
            }
            .background(Color.white)
            .clipShape(RoundedCorner(radius: theme.radius, corners: [.topLeft, .topRight]))
            .overlay(
                RoundedCorner(radius: theme.radius, corners: [.topLeft, .topRight])
                    .stroke(Color.black.opacity(0.08), lineWidth: 1)
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .ignoresSafeArea(edges: .bottom)
        .sheet(item: $safariFallbackRoute) { route in
            SafariFallbackView(url: route.url)
        }
    }

    private func bodyColumnBottomPadding() -> CGFloat {
        let base: CGFloat = 8
        let tightenedSafeArea = max(8, keyWindowBottomSafeAreaInset - 12)
        return base + tightenedSafeArea
    }

    private var keyWindowBottomSafeAreaInset: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?
            .safeAreaInsets.bottom ?? 0
    }

    private var headerBackground: Color {
        Color(red: 0.95, green: 0.95, blue: 0.95)
    }

    private var supportingTextColor: Color {
        Color.black.opacity(0.45)
    }

    @ViewBuilder
    private func headerBar(
        orderLine: String?,
        fontSize: CGFloat,
        closeButtonSize: CGFloat,
        closeButtonIconSize: CGFloat,
        closeButtonCornerRadius: CGFloat,
        closeButtonBG: Color,
        closeButtonIconColor: Color
    ) -> some View {
        ZStack {
            if config.showOrderLine, let orderLine, !orderLine.isEmpty {
                Text(orderLine.uppercased())
                    .font(.system(size: max(11, fontSize - 3), weight: .semibold))
                    .tracking(0.5)
                    .foregroundColor(Color(red: 0.42, green: 0.42, blue: 0.42))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .padding(.horizontal, closeButtonSize + 20)
            }

            HStack {
                Spacer()
                if config.showCloseButton {
                    Button {
                        switch closeButtonAction {
                        case .minimize:
                            onMinimize()
                        case .dismiss:
                            onDismiss()
                        }
                    } label: {
                        Image(systemName: closeButtonAction == .minimize ? "minus" : "xmark")
                            .font(.system(size: closeButtonIconSize, weight: .bold))
                            .foregroundColor(closeButtonIconColor)
                            .frame(width: closeButtonSize, height: closeButtonSize)
                            .background(closeButtonBG)
                            .clipShape(RoundedRectangle(cornerRadius: max(4, closeButtonCornerRadius)))
                            .overlay(
                                RoundedRectangle(cornerRadius: max(4, closeButtonCornerRadius))
                                    .stroke(Color.black.opacity(0.08), lineWidth: 1)
                            )
                    }
                    .accessibilityLabel(
                        closeButtonAction == .minimize
                        ? "Minimize reward offer"
                        : "Close reward offer"
                    )
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .frame(minHeight: 48)
        .background(headerBackground)
    }

    @ViewBuilder
    private func heroBanner(
        reward: DelightPopupRewardDTO?,
        height: CGFloat,
        objectFit: String
    ) -> some View {
        Group {
            if let imageUrl = reward?.postPopupMobileImage ?? reward?.postPopupWebImage,
               let imageURL = URL(string: imageUrl) {
                if imageURL.pathExtension.lowercased() == "svg" {
                    SVGRemoteImageView(url: imageURL, objectFit: cssObjectFit(from: objectFit))
                        .id(imageURL)
                } else {
                    RemoteRasterImageView(
                        url: imageURL,
                        contentMode: contentMode(from: objectFit)
                    ) {
                        imagePlaceholder
                    }
                    .id(imageURL)
                }
            } else {
                imagePlaceholder
            }
        }
        .frame(height: height)
        .frame(maxWidth: .infinity)
        .clipped()
    }

    private func rewardClaimKey(_ reward: DelightPopupRewardDTO?, index: Int) -> String {
        if let id = reward?.id?.trimmingCharacters(in: .whitespacesAndNewlines), !id.isEmpty {
            return id
        }
        return "index-\(index)"
    }

    private func nextUnclaimedIndex(
        after index: Int,
        rewards: [DelightPopupRewardDTO],
        claimed: Set<String>
    ) -> Int? {
        guard rewards.count > 1 else { return nil }
        for offset in 1..<rewards.count {
            let candidate = (index + offset) % rewards.count
            let key = rewardClaimKey(rewards[candidate], index: candidate)
            if !claimed.contains(key) {
                return candidate
            }
        }
        return nil
    }

    private func termsDisclaimer(_ termsHtml: String?) -> String? {
        let plain = termsHtml?
            .htmlToPlainText()
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !plain.isEmpty else { return nil }
        return plain
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
    private func footerLinks(
        reward: DelightPopupRewardDTO?,
        popupLocale: DelightPopupLocaleDTO?,
        lineSpacing: CGFloat
    ) -> some View {
        let partnerTermsLabel = partnerTermsLinkLabel(popupLocale)
        let poweredByLabel = popupLocale?.poweredBy ?? "Powered by RewardsBag"
        let privacyLabel = popupLocale?.privacyPolicy ?? "Privacy Policy"
        HStack(spacing: 6) {
            footerLink(title: partnerTermsLabel, rawUrl: mirrorOptionalString(label: "partnerTermsUrl", in: reward))
            Text("|")
                .foregroundColor(supportingTextColor)
                .accessibilityHidden(true)
            footerLink(title: poweredByLabel, rawUrl: mirrorOptionalString(label: "poweredByUrl", in: reward))
            Text("|")
                .foregroundColor(supportingTextColor)
                .accessibilityHidden(true)
            footerLink(title: privacyLabel, rawUrl: mirrorOptionalString(label: "privacyPolicyUrl", in: reward))
        }
        .font(.system(size: 10, weight: .medium))
        .foregroundColor(Color.black.opacity(0.55))
        .lineSpacing(lineSpacing)
        .lineLimit(1)
        .minimumScaleFactor(0.65)
        .allowsTightening(true)
        .frame(maxWidth: .infinity)
    }

    private func footerLink(title: String, rawUrl: String?) -> some View {
        Button {
            guard let url = resolvedCTAUrl(from: rawUrl) else { return }
            openRewardURL(url)
        } label: {
            Text(title)
                .underline()
        }
        .buttonStyle(PlainButtonStyle())
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

    private var imagePlaceholder: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(
                LinearGradient(
                    colors: [Color.gray.opacity(0.22), Color.gray.opacity(0.08)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                Image(systemName: "photo")
                    .font(.system(size: 36, weight: .light))
                    .foregroundColor(Color.black.opacity(0.35))
            )
    }

    private func numberedSliderControls(
        rewardCount: Int,
        selectedIndex: Int,
        activeColor: Color,
        inactiveColor: Color,
        arrowColor: Color
    ) -> some View {
        HStack(spacing: 14) {
            Button {
                guard rewardCount > 0 else { return }
                currentRewardIndex = (selectedIndex - 1 + rewardCount) % rewardCount
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(arrowColor)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(PlainButtonStyle())
            .accessibilityLabel("Previous reward")

            HStack(spacing: 10) {
                ForEach(0..<rewardCount, id: \.self) { index in
                    Button {
                        currentRewardIndex = index
                    } label: {
                        Text("\(index + 1)")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(index == selectedIndex ? Color.white : Color.black.opacity(0.55))
                            .frame(width: 28, height: 28)
                            .background(index == selectedIndex ? activeColor : inactiveColor)
                            .clipShape(Circle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    .accessibilityLabel("Go to reward \(index + 1)")
                    .accessibilityAddTraits(index == selectedIndex ? .isSelected : [])
                }
            }

            Button {
                guard rewardCount > 0 else { return }
                currentRewardIndex = (selectedIndex + 1) % rewardCount
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(arrowColor)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(PlainButtonStyle())
            .accessibilityLabel("Next reward")
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

    private func lineSpacing(fontSize: CGFloat, lineHeight: Double) -> CGFloat {
        max(0, (CGFloat(lineHeight) * fontSize) - fontSize)
    }

    private func contentMode(from objectFit: String) -> ContentMode {
        objectFit == "cover" ? .fill : .fit
    }

    private func cssObjectFit(from objectFit: String) -> String {
        switch objectFit {
        case "contain":
            return "contain"
        case "fill":
            return "fill"
        case "none":
            return "none"
        case "scale-down":
            return "scale-down"
        default:
            return "cover"
        }
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

private struct RemoteRasterImageView<Placeholder: View>: View {
    let url: URL
    let contentMode: ContentMode
    @ViewBuilder var placeholder: () -> Placeholder

    @StateObject private var loader = RemoteRasterImageLoader()

    var body: some View {
        Group {
            if let image = loader.image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else {
                placeholder()
            }
        }
        .onAppear {
            loader.load(from: url)
        }
        .onChange(of: url) { newURL in
            loader.load(from: newURL)
        }
    }
}

private final class RemoteRasterImageLoader: ObservableObject {
    @Published var image: UIImage?
    private var currentURL: URL?

    func load(from url: URL) {
        if currentURL == url, image != nil {
            return
        }
        currentURL = url
        image = nil
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let self, self.currentURL == url else { return }
            guard let data, let image = UIImage(data: data) else { return }
            DispatchQueue.main.async {
                self.image = image
            }
        }.resume()
    }
}

private struct SVGRemoteImageView: UIViewRepresentable {
    let url: URL
    let objectFit: String

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
                object-fit: \(objectFit);
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

private struct RoundedCorner: Shape {
    var radius: CGFloat
    var corners: UIRectCorner

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

private extension String {
    func htmlToPlainText() -> String {
        replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
