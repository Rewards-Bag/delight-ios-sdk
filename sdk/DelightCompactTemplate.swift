import SwiftUI

struct DelightCompactTemplate: View {
    let decision: DelightDecisionResponse
    let theme: DelightPopupTheme
    let onPrimary: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            Text(decision.content.title)
                .font(.headline)
                .multilineTextAlignment(.center)

            if let subtitle = decision.content.subtitle {
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button(decision.content.primaryCta ?? "Continue") {
                onPrimary()
            }
            .buttonStyle(.borderedProminent)
            .tint(theme.primary)

            Button(decision.content.secondaryCta ?? "Dismiss") {
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
