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
    var onRewardsExhausted: () -> Void = {}
    @Binding var currentRewardIndex: Int
    @Binding var claimedRewardIds: Set<String>
    @Environment(\.openURL) private var openURL
    @State private var safariFallbackRoute: SafariFallbackRoute?

    var body: some View {
        let allRewards = config.resolvedRewards
        let visibleSourceIndices = unclaimedSourceIndices(rewards: allRewards, claimed: claimedRewardIds)
        let sourceIndex = resolvedSourceIndex(
            current: currentRewardIndex,
            visibleSourceIndices: visibleSourceIndices
        )
        let reward = allRewards.indices.contains(sourceIndex) ? allRewards[sourceIndex] : nil
        let rewardLocale = config.resolvedRewardLocale(for: reward)
        let popupLocale = config.resolvedPopupLocale
        let orderLineFontSize = CGFloat(config.orderLineFontSize)
        let headlineFontSize = CGFloat(config.headlineFontSize)
        let headlineLineSpacing = lineSpacing(fontSize: headlineFontSize, lineHeight: config.headlineLineHeight)
        let descriptionFontSize = CGFloat(config.descriptionFontSize)
        let descriptionLineSpacing = lineSpacing(fontSize: descriptionFontSize, lineHeight: config.descriptionLineHeight)
        let ctaButtonFontSize = CGFloat(config.ctaButtonFontSize)
        let ctaButtonLineSpacing = lineSpacing(fontSize: ctaButtonFontSize, lineHeight: config.ctaButtonLineHeight)
        let footerLinksLineSpacing = lineSpacing(fontSize: 11, lineHeight: config.footerLinksLineHeight)
        let closeButtonSize = min(CGFloat(config.closeButtonSize), 36)
        let closeButtonIconSize = min(CGFloat(config.closeButtonIconSize), 16)
        let closeButtonCornerRadius = CGFloat(config.closeButtonCornerRadius)
        let widgetImageObjectFit = config.widgetImageObjectFit
        let heroBannerHeight: CGFloat = 168

        ZStack {
            theme.overlay
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                headerBar(
                    orderLine: headerLine(rewardLocale: rewardLocale, popupLocale: popupLocale),
                    fontSize: orderLineFontSize,
                    closeButtonSize: min(28, closeButtonSize),
                    closeButtonIconSize: closeButtonIconSize,
                    closeButtonCornerRadius: max(8, closeButtonCornerRadius)
                )

                heroBanner(
                    reward: reward,
                    height: heroBannerHeight,
                    objectFit: widgetImageObjectFit
                )

                VStack(spacing: 10) {
                    if config.showHeadline {
                        Text(rewardLocale?.headline ?? "Thanks for your order")
                            .font(.system(size: min(max(headlineFontSize, 18), 20), weight: .bold))
                            .multilineTextAlignment(.center)
                            .foregroundColor(.black)
                            .lineSpacing(headlineLineSpacing)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 20)
                            .padding(.top, 16)
                    }

                    if config.showDescription,
                       let description = firstDescriptionParagraph(rewardLocale?.description),
                       !description.isEmpty {
                        Text(description)
                            .font(.system(size: min(descriptionFontSize, 14), weight: .regular))
                            .multilineTextAlignment(.center)
                            .foregroundColor(Color(red: 0.22, green: 0.24, blue: 0.27))
                            .lineSpacing(descriptionLineSpacing)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 20)
                    }

                    if config.showCTAButton {
                        HStack(alignment: .center, spacing: 12) {
                            Button {
                                let claimedSourceIndex = sourceIndex
                                let claimKey = rewardClaimKey(reward, index: claimedSourceIndex)
                                openCTAUrl(reward?.ctaUrl) {
                                    claimedRewardIds.insert(claimKey)
                                    onPrimary(reward?.id)
                                    advanceAfterDismissing(
                                        sourceIndex: claimedSourceIndex,
                                        rewards: allRewards
                                    )
                                }
                            } label: {
                                Text(rewardLocale?.cta ?? popupLocale?.cta ?? "Claim now")
                                    .font(.system(size: 15, weight: .heavy))
                                    .lineSpacing(ctaButtonLineSpacing)
                                    .multilineTextAlignment(.center)
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 44)
                                    .background(theme.primary)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            .buttonStyle(PlainButtonStyle())

                            Button {
                                let claimedSourceIndex = sourceIndex
                                let claimKey = rewardClaimKey(reward, index: claimedSourceIndex)
                                claimedRewardIds.insert(claimKey)
                                advanceAfterDismissing(
                                    sourceIndex: claimedSourceIndex,
                                    rewards: allRewards
                                )
                            } label: {
                                Text(secondaryCtaLabel(popupLocale))
                                    .font(.system(size: 15, weight: .regular))
                                    .foregroundColor(.black)
                                    .lineLimit(2)
                                    .minimumScaleFactor(0.8)
                                    .multilineTextAlignment(.center)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .fixedSize(horizontal: true, vertical: false)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 6)
                    }

                    if let terms = termsDisclaimer(rewardLocale?.terms), !terms.isEmpty {
                        Text(terms)
                            .font(.system(size: 11, weight: .regular))
                            .foregroundColor(supportingTextColor)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                            .padding(.top, 2)
                    }

                    if config.showFooterLinks {
                        footerLinks(
                            reward: reward,
                            rewardLocale: rewardLocale,
                            popupLocale: popupLocale,
                            lineSpacing: footerLinksLineSpacing
                        )
                        .padding(.top, 2)
                    }
                }
                .padding(.bottom, max(10, keyWindowBottomSafeAreaInset - 18))
                .background(Color.white)
            }
            .frame(maxWidth: .infinity)
            .background(Color.white)
            .clipShape(RoundedCorner(radius: max(theme.radius, 16), corners: [.topLeft, .topRight]))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .ignoresSafeArea(edges: .bottom)
        .sheet(item: $safariFallbackRoute) { route in
            SafariFallbackView(url: route.url)
        }
        .onAppear {
            syncCurrentRewardIndexToVisibleRewards(allRewards: allRewards)
        }
        .onChange(of: claimedRewardIds) { _ in
            syncCurrentRewardIndexToVisibleRewards(allRewards: allRewards)
        }
    }

    private var keyWindowBottomSafeAreaInset: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?
            .safeAreaInsets.bottom ?? 0
    }

    private var supportingTextColor: Color {
        Color(red: 0.42, green: 0.45, blue: 0.48)
    }

    private func secondaryCtaLabel(_ popupLocale: DelightPopupLocaleDTO?) -> String {
        let label = popupLocale?.secondaryCta?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return label.isEmpty ? "No thanks" : label
    }

    @ViewBuilder
    private func headerBar(
        orderLine: String?,
        fontSize: CGFloat,
        closeButtonSize: CGFloat,
        closeButtonIconSize: CGFloat,
        closeButtonCornerRadius: CGFloat
    ) -> some View {
        HStack(alignment: .center, spacing: 10) {
            if config.showHostLogo,
               let hostLogoUrl = config.partnerLogo,
               let hostLogoURL = URL(string: hostLogoUrl) {
                RemoteRasterImageView(url: hostLogoURL, contentMode: .fit, templateTint: .white) {
                    Color.clear
                }
                .frame(width: 50, height: 18)
                .clipped()
                .accessibilityLabel(config.hostDisplayName ?? "GWR")
            }

            if config.showOrderLine, let orderLine, !orderLine.isEmpty {
                Text(orderLine)
                    .font(.system(size: max(13, min(fontSize, 14)), weight: .semibold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Spacer(minLength: 0)
            }

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
                        .font(.system(size: max(14, closeButtonIconSize), weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: closeButtonSize, height: closeButtonSize)
                        .background(Color.black.opacity(0.18))
                        .clipShape(RoundedRectangle(cornerRadius: closeButtonCornerRadius))
                }
                .buttonStyle(PlainButtonStyle())
                .accessibilityLabel(
                    closeButtonAction == .minimize
                    ? "Minimize reward offer"
                    : "Close reward offer"
                )
            }
        }
        .padding(.leading, 12)
        .padding(.trailing, 8)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, minHeight: 40)
        .clipped()
        .background(theme.primary)
    }

    @ViewBuilder
    private func heroBanner(
        reward: DelightPopupRewardDTO?,
        height: CGFloat,
        objectFit: String
    ) -> some View {
        GeometryReader { geo in
            ZStack {
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
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .clipped()
    }

    private func rewardClaimKey(_ reward: DelightPopupRewardDTO?, index: Int) -> String {
        if let id = reward?.id?.trimmingCharacters(in: .whitespacesAndNewlines), !id.isEmpty {
            return id
        }
        return "index-\(index)"
    }

    private func unclaimedSourceIndices(
        rewards: [DelightPopupRewardDTO],
        claimed: Set<String>
    ) -> [Int] {
        rewards.indices.filter { index in
            let key = rewardClaimKey(rewards[index], index: index)
            return !claimed.contains(key)
        }
    }

    private func resolvedSourceIndex(current: Int, visibleSourceIndices: [Int]) -> Int {
        guard let first = visibleSourceIndices.first else { return 0 }
        if visibleSourceIndices.contains(current) {
            return current
        }
        return first
    }

    private func advanceAfterDismissing(sourceIndex: Int, rewards: [DelightPopupRewardDTO]) {
        let remaining = unclaimedSourceIndices(rewards: rewards, claimed: claimedRewardIds)
        if let next = remaining.first(where: { $0 > sourceIndex }) {
            currentRewardIndex = next
            return
        }
        if remaining.isEmpty {
            onRewardsExhausted()
            return
        }
        currentRewardIndex = remaining[0]
    }

    private func syncCurrentRewardIndexToVisibleRewards(allRewards: [DelightPopupRewardDTO]) {
        let visible = unclaimedSourceIndices(rewards: allRewards, claimed: claimedRewardIds)
        guard let first = visible.first else { return }
        if !visible.contains(currentRewardIndex) {
            currentRewardIndex = first
        }
    }

    private func firstDescriptionParagraph(_ html: String?) -> String? {
        guard let html else { return nil }
        if let match = html.range(of: "(?is)<p[^>]*>(.*?)</p>", options: .regularExpression) {
            let text = String(html[match]).htmlToPlainText()
            if !text.isEmpty { return text }
        }
        let text = html.htmlToPlainText()
        return text.isEmpty ? nil : text
    }

    private func termsDisclaimer(_ termsHtml: String?) -> String? {
        let plain = termsHtml?
            .htmlToPlainText()
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !plain.isEmpty else { return nil }
        return plain
    }

    private func headerLine(
        rewardLocale: DelightPopupRewardLocaleDTO?,
        popupLocale: DelightPopupLocaleDTO?
    ) -> String? {
        let thankyouLine = rewardLocale?.thankyouLine?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !thankyouLine.isEmpty { return thankyouLine }
        let orderLine = popupLocale?.orderLine?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return orderLine.isEmpty ? nil : orderLine
    }

    private func partnerTermsLinkLabel(
        rewardLocale: DelightPopupRewardLocaleDTO?,
        popupLocale: DelightPopupLocaleDTO?
    ) -> String {
        footerLabel(rewardLocale?.partnerTermsContent, popupLocale?.partnerTerms, fallback: "")
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
        rewardLocale: DelightPopupRewardLocaleDTO?,
        popupLocale: DelightPopupLocaleDTO?,
        lineSpacing: CGFloat
    ) -> some View {
        let partnerTermsLabel = partnerTermsLinkLabel(rewardLocale: rewardLocale, popupLocale: popupLocale)
        let poweredByLabel = footerLabel(
            rewardLocale?.poweredByContent,
            popupLocale?.poweredBy,
            fallback: ""
        )
        let privacyLabel = footerLabel(
            rewardLocale?.privacyContent,
            popupLocale?.privacyPolicy,
            fallback: ""
        )
        let partnerTermsURL = mirrorOptionalString(label: "partnerTermsUrl", in: reward)
        HStack(spacing: 0) {
            if !partnerTermsLabel.isEmpty {
                footerLink(title: partnerTermsLabel, rawUrl: partnerTermsURL)
                if !poweredByLabel.isEmpty || !privacyLabel.isEmpty {
                    footerSeparator()
                }
            }
            if !poweredByLabel.isEmpty {
                footerLink(title: poweredByLabel, rawUrl: mirrorOptionalString(label: "poweredByUrl", in: reward))
                if !privacyLabel.isEmpty {
                    footerSeparator()
                }
            }
            if !privacyLabel.isEmpty {
                footerLink(title: privacyLabel, rawUrl: mirrorOptionalString(label: "privacyPolicyUrl", in: reward))
            }
        }
        .font(.system(size: 10, weight: .regular))
        .foregroundColor(supportingTextColor)
        .lineSpacing(lineSpacing)
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 8)
    }

    private func footerLabel(_ rewardValue: String?, _ popupValue: String?, fallback: String) -> String {
        let rewardLabel = rewardValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !rewardLabel.isEmpty { return rewardLabel }
        let popupLabel = popupValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !popupLabel.isEmpty { return popupLabel }
        return fallback
    }

    private func footerSeparator() -> some View {
        Text(" · ")
            .foregroundColor(supportingTextColor)
            .lineLimit(1)
            .fixedSize()
            .accessibilityHidden(true)
    }

    private func footerLink(title: String, rawUrl: String?) -> some View {
        Button {
            guard let url = resolvedCTAUrl(from: rawUrl) else { return }
            openRewardURL(url)
        } label: {
            Text(title)
                .underline()
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
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
    var templateTint: Color? = nil
    @ViewBuilder var placeholder: () -> Placeholder

    @StateObject private var loader = RemoteRasterImageLoader()

    var body: some View {
        Group {
            if let image = loader.image {
                if let templateTint {
                    Image(uiImage: image.withRenderingMode(.alwaysTemplate))
                        .resizable()
                        .renderingMode(.template)
                        .foregroundColor(templateTint)
                        .aspectRatio(contentMode: contentMode)
                } else {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: contentMode)
                }
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
