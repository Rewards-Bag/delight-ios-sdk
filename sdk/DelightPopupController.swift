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

    @Published var isPresented = false
    @Published var state: DelightPopupState = .idle
    @Published var payload: DelightRequestPayload?
    @Published var callbacks: DelightCallbacks = .init()
    @Published var config: DelightConfigDTO?
    @Published var ignoreLocalRulesForTesting = false
    var ignoreCooldownForLocalDevelopment = false

    private var currentRewardId: String?
    private var didClickCurrentReward = false
    private var didRecordIgnoreForCurrentPresentation = false
    private var didCommitVisibleImpression = false
    private var didRegisterVisibleSession = false
    private var initializationErrorMessage: String?

    private init() {}

    func show(payload: DelightRequestPayload, callbacks: DelightCallbacks) {
        self.payload = payload
        self.callbacks = callbacks
        if let initializationErrorMessage {
            handleNonDisplayableError(initializationErrorMessage)
            return
        }
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
        recordIgnoreIfNoClick()
        isPresented = false
        state = .hidden
        resetPresentationTracking()
    }

    func handleSheetDidDismiss() {
        recordIgnoreIfNoClick()
        callbacks.onDismiss?()
        resetPresentationTracking()
        state = .hidden
    }

    func markPopupBecameVisible() {
        guard !didRegisterVisibleSession else { return }
        didRegisterVisibleSession = true
        let now = Date()
        commitVisibleImpressionIfNeeded(at: now)
        callbacks.onImpression?(currentRewardId)
    }

    func markDismissedByCloseButton() {
        recordIgnoreIfNoClick()
    }

    func markRewardClicked(_ rewardId: String?) {
        didClickCurrentReward = true
        if let payload {
            DelightRewardSelectionService.recordClick(payload: payload, rewardId: rewardId)
        }
    }

    func reportInitializationError(_ message: String) {
        initializationErrorMessage = message
    }

    func clearInitializationError() {
        initializationErrorMessage = nil
    }

    private func fetchConfigAndBuildPopup() async {
        guard payload != nil else {
            handleNonDisplayableError("Missing payload")
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
                handleNonDisplayableError("SDK not initialized and bundled config is unavailable.")
                return
            }
        }

        guard let popup = resolvedConfig.popup, popup.enabled == true else {
            handleNonDisplayableError("Popup config missing or disabled")
            return
        }

        guard DelightTemplateRegistry.supports(templateId: resolvedConfig.templateId) else {
            handleNonDisplayableError("Unsupported template: \(resolvedConfig.templateId)")
            return
        }

        guard let payload else {
            handleNonDisplayableError("Missing payload")
            return
        }

        guard let selectedConfig = DelightRewardSelectionService.selectConfig(
            from: resolvedConfig,
            payload: payload,
            ignoreLocalRulesForTesting: ignoreLocalRulesForTesting,
            ignoreCooldownForLocalDevelopment: ignoreCooldownForLocalDevelopment
        ) else {
            callbacks.onError?("No eligible rewards available for current context.")
            isPresented = false
            state = .hidden
            resetPresentationTracking()
            return
        }

        let selectedRewardId = selectedConfig.popup?.rewards?.first?.id
        let theme = DelightPopupTheme.fromBrandTheme(selectedConfig.popup?.theme)
        state = .ready(selectedConfig, theme, selectedRewardId)
        currentRewardId = selectedRewardId
        didClickCurrentReward = false
        isPresented = true
    }

    private func commitVisibleImpressionIfNeeded(at date: Date) {
        guard
            !didCommitVisibleImpression,
            let payload,
            let rewardId = currentRewardId,
            !rewardId.isEmpty
        else { return }
        didCommitVisibleImpression = true
        DelightRewardSelectionService.recordVisibleImpression(
            payload: payload,
            rewardId: rewardId,
            at: date
        )
    }

    private func recordIgnoreIfNoClick() {
        guard
            !didRecordIgnoreForCurrentPresentation,
            let payload,
            let rewardId = currentRewardId,
            !rewardId.isEmpty,
            !didClickCurrentReward
        else { return }

        didRecordIgnoreForCurrentPresentation = true
        DelightRewardSelectionService.recordIgnore(
            payload: payload,
            rewardId: rewardId,
            at: Date()
        )
    }

    private func resetPresentationTracking() {
        currentRewardId = nil
        didClickCurrentReward = false
        didRecordIgnoreForCurrentPresentation = false
        didCommitVisibleImpression = false
        didRegisterVisibleSession = false
    }

    private func handleNonDisplayableError(_ message: String) {
        callbacks.onError?(message)
        isPresented = false
        state = .hidden
        resetPresentationTracking()
    }
}
