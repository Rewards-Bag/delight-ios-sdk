import SwiftUI

struct DelightCompactTemplate: View {
    let config: DelightConfigDTO
    let theme: DelightPopupTheme
    let onPrimary: (String?) -> Void
    let onDismiss: () -> Void

    var body: some View {
        let reward = config.resolvedRewards.first
        let rewardLocale = config.resolvedRewardLocale(for: reward)
        let popupLocale = config.resolvedPopupLocale

        VStack(spacing: 10) {
            Text(rewardLocale?.headline ?? "Thanks for your order")
                .font(.headline)
                .multilineTextAlignment(.center)

            if let subtitle = popupLocale?.orderLine {
                Text(subtitle)
                    .font(.footnote)
                    .foregroundColor(Color(UIColor.secondaryLabel))
                    .multilineTextAlignment(.center)
            }

            Button(rewardLocale?.cta ?? popupLocale?.cta ?? "Continue") {
                onPrimary(reward?.id)
            }
            .buttonStyle(.plain)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(theme.primary)
            .clipShape(Capsule())

            Button(popupLocale?.secondaryCta ?? "Dismiss") {
                onDismiss()
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: theme.radius))
        .modifier(DelightCompactSheetDetentModifier())
    }
}

private struct DelightCompactSheetDetentModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            content.presentationDetents([.height(260)])
        } else {
            content
        }
    }
}
