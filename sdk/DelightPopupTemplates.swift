import SwiftUI

enum DelightTemplateRegistry {
    static let supportedTemplateIds: Set<String> = [
        "modal_card_v1",
        "modal_compact_v1"
    ]

    static func supports(templateId: String) -> Bool {
        supportedTemplateIds.contains(templateId)
    }

    @ViewBuilder
    static func view(
        for decision: DelightDecisionResponse,
        theme: DelightPopupTheme,
        onPrimary: @escaping () -> Void,
        onDismiss: @escaping () -> Void
    ) -> some View {
        switch decision.templateId {
        case "modal_compact_v1":
            DelightCompactTemplate(
                decision: decision,
                theme: theme,
                onPrimary: onPrimary,
                onDismiss: onDismiss
            )
        default:
            DelightHeroOfferTemplate(
                decision: decision,
                theme: theme,
                onPrimary: onPrimary,
                onDismiss: onDismiss
            )
        }
    }
}
