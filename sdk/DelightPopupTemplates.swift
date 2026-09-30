import SwiftUI

enum DelightTemplateRegistry {
    static let supportedTemplateIds: Set<String> = [
        DelightTemplateID.stagecoachModal,
        DelightTemplateID.modalCompact,
        DelightTemplateID.gwrModal
    ]

    static func supports(templateId: String) -> Bool {
        supportedTemplateIds.contains(templateId)
    }

    @ViewBuilder
    static func view(
        for config: DelightConfigDTO,
        theme: DelightPopupTheme,
        closeButtonAction: DelightPopupCloseButtonAction = .minimize,
        onMinimize: @escaping () -> Void = {},
        onPrimary: @escaping (String?) -> Void,
        onDismiss: @escaping () -> Void,
        currentRewardIndex: Binding<Int> = .constant(0),
        claimedRewardIds: Binding<Set<String>> = .constant([])
    ) -> some View {
        switch config.templateId {
        case DelightTemplateID.modalCompact:
            DelightCompactTemplate(
                config: config,
                theme: theme,
                onPrimary: onPrimary,
                onDismiss: onDismiss
            )
        case DelightTemplateID.gwrModal:
            DelightGWRTemplate(
                config: config,
                theme: theme,
                closeButtonAction: closeButtonAction,
                onMinimize: onMinimize,
                onPrimary: onPrimary,
                onDismiss: onDismiss,
                currentRewardIndex: currentRewardIndex,
                claimedRewardIds: claimedRewardIds
            )
        default:
            DelightStagecoachTemplate(
                config: config,
                theme: theme,
                closeButtonAction: closeButtonAction,
                onMinimize: onMinimize,
                onPrimary: onPrimary,
                onDismiss: onDismiss
            )
        }
    }
}
