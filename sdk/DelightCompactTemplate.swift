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
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button(rewardLocale?.cta ?? popupLocale?.cta ?? "Continue") {
                onPrimary(reward?.id)
            }
            .buttonStyle(.borderedProminent)
            .tint(theme.primary)

            Button(popupLocale?.secondaryCta ?? "Dismiss") {
                onDismiss()
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: theme.radius))
        .presentationDetents([.height(260)])
    }
}
