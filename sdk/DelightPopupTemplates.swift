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
        for config: DelightConfigDTO,
        theme: DelightPopupTheme,
        onPrimary: @escaping (String?) -> Void,
        onDismiss: @escaping () -> Void
    ) -> some View {
        switch config.templateId {
        case "modal_compact_v1":
            DelightCompactTemplate(
                config: config,
                theme: theme,
                onPrimary: onPrimary,
                onDismiss: onDismiss
            )
        default:
            DelightHeroOfferTemplate(
                config: config,
                theme: theme,
                onPrimary: onPrimary,
                onDismiss: onDismiss
            )
        }
    }
}
