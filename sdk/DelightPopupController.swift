import Combine
import Foundation

enum DelightPopupState {
    case idle
    case loading
    case ready(DelightConfigDTO, DelightPopupTheme, String?)
    case hidden
    case failed(String)
}

@MainActor
final class DelightPopupController: ObservableObject {
    static let shared = DelightPopupController()
    private static let minimumVisibleSecondsForIgnore: TimeInterval = 3

    @Published var isPresented = false
    @Published var state: DelightPopupState = .idle
    @Published var payload: DelightRequestPayload?
    @Published var callbacks: DelightCallbacks = .init()
    @Published var config: DelightConfigDTO?
    @Published var ignoreLocalRulesForTesting = false
    private var currentRewardId: String?
    private var presentedAt: Date?
    private var didClickCurrentReward = false
    private var dismissedViaTemplateCloseButton = false

    private init() {}

    func show(payload: DelightRequestPayload, callbacks: DelightCallbacks) {
        self.payload = payload
        self.callbacks = callbacks
        self.state = .loading
        resetPresentationTracking()
        Task { await fetchConfigAndBuildPopup() }
    }

    func show() {
        isPresented = true
        if case .ready = state {
            return
        }
        state = .idle
    }

    func dismiss() {
        processPotentialIgnore()
        isPresented = false
        callbacks.onDismiss?()
        state = .hidden
        resetPresentationTracking()
    }

    func markDismissedByCloseButton() {
        dismissedViaTemplateCloseButton = true
    }

    func markRewardClicked(_ rewardId: String?) {
        didClickCurrentReward = true
        if let payload {
            DelightRewardSelectionService.recordClick(
                payload: payload,
                rewardId: rewardId,
                ignoreLocalRulesForTesting: ignoreLocalRulesForTesting
            )
        }
    }

    func handleSheetDidDismiss() {
        // Covers system gestures (swipe-down/background dismiss) where template onDismiss is not called.
        processPotentialIgnore()
        resetPresentationTracking()
        state = .hidden
    }

    private func fetchConfigAndBuildPopup() async {
        guard payload != nil else {
            state = .failed("Missing payload")
            return
        }

        let resolvedConfig: DelightConfigDTO
        if let config {
            resolvedConfig = config
        } else {
            do {
                let bundledConfig = try DelightConfigService.loadBundledConfig()
                self.config = bundledConfig
                resolvedConfig = bundledConfig
            } catch {
                state = .failed("SDK not initialized and bundled config is unavailable.")
                return
            }
        }

        guard let popup = resolvedConfig.popup, popup.enabled == true else {
            state = .failed("Popup config missing or disabled")
            return
        }

        guard DelightTemplateRegistry.supports(templateId: resolvedConfig.templateId) else {
            state = .failed("Unsupported template: \(resolvedConfig.templateId)")
            return
        }

        guard let payload else {
            state = .failed("Missing payload")
            return
        }

        guard let selectedConfig = DelightRewardSelectionService.selectConfig(
            from: resolvedConfig,
            payload: payload,
            ignoreLocalRulesForTesting: ignoreLocalRulesForTesting
        ) else {
            isPresented = false
            state = .hidden
            resetPresentationTracking()
            return
        }

        let selectedRewardId = selectedConfig.popup?.rewards?.first?.id
        let theme = DelightPopupTheme.fromBrandTheme(selectedConfig.popup?.theme)
        state = .ready(selectedConfig, theme, selectedRewardId)
        currentRewardId = selectedRewardId
        presentedAt = Date()
        didClickCurrentReward = false
        dismissedViaTemplateCloseButton = false
        isPresented = true
    }

    private func processPotentialIgnore() {
        guard
            let payload,
            let rewardId = currentRewardId,
            !rewardId.isEmpty,
            !didClickCurrentReward
        else { return }

        let now = Date()
        let visibleDuration = now.timeIntervalSince(presentedAt ?? now)
        let isIgnored = dismissedViaTemplateCloseButton || visibleDuration >= Self.minimumVisibleSecondsForIgnore
        if isIgnored {
            DelightRewardSelectionService.recordIgnore(
                payload: payload,
                rewardId: rewardId,
                at: now,
                ignoreLocalRulesForTesting: ignoreLocalRulesForTesting
            )
        }
    }

    private func resetPresentationTracking() {
        currentRewardId = nil
        presentedAt = nil
        didClickCurrentReward = false
        dismissedViaTemplateCloseButton = false
    }
}
