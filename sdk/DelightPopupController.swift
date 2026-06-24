import Combine
import Foundation
#if canImport(UIKit)
import UIKit
#endif

enum DelightPopupCloseButtonAction {
    case minimize
    case dismiss
}

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
    @Published var isMinimized = false
    @Published var closeButtonShowsDismiss = false
    @Published var state: DelightPopupState = .idle
    @Published var payload: DelightRequestPayload?
    @Published var callbacks: DelightCallbacks = .init()
    @Published var config: DelightConfigDTO?
    @Published var consentGranted = true

    private var currentRewardId: String?
    private var didClickCurrentReward = false
    private var didRecordIgnoreForCurrentPresentation = false
    private var didCommitVisibleImpression = false
    private var didRegisterVisibleSession = false
    private var initializationErrorMessage: String?
    private var initializedBrandName: String?

    private init() {}

    func show(payload: DelightRequestPayload, callbacks: DelightCallbacks) {
        self.payload = payload
        self.callbacks = callbacks
        hideMinimizedBadgeOverlay()
        hidePopupOverlay()
        isMinimized = false
        closeButtonShowsDismiss = false
        guard consentGranted else {
            handleNonDisplayableError("Consent not granted. Popup display is disabled.")
            return
        }
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
        hidePopupOverlay()
        hideMinimizedBadgeOverlay()
        isMinimized = false
        closeButtonShowsDismiss = false
        isPresented = false
        state = .hidden
        callbacks.onDismiss?()
        resetPresentationTracking()
    }

    /// Collapses the popup to a floating present icon without recording an ignore.
    func minimize() {
        guard case .ready = state else { return }
        hidePopupOverlay()
        isMinimized = true
        isPresented = false
        showMinimizedBadgeOverlay()
    }

    /// Reopens the reward popup from the minimized present icon (close button becomes X).
    func expandFromMinimized() {
        guard case .ready = state else { return }
        hideMinimizedBadgeOverlay()
        closeButtonShowsDismiss = true
        isMinimized = false
        isPresented = true
        showPopupOverlay()
    }

    func markPopupBecameVisible() {
        guard !didRegisterVisibleSession else { return }
        didRegisterVisibleSession = true
        let now = Date()
        commitVisibleImpressionIfNeeded(at: now)
        triggerBackendImpressionTracking()
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
        triggerBackendRewardClaimTracking(rewardId: rewardId)
    }

    func reportInitializationError(_ message: String) {
        initializationErrorMessage = message
    }

    func clearInitializationError() {
        initializationErrorMessage = nil
    }

    func setInitializedBrandName(_ value: String) {
        initializedBrandName = value
    }

    func isConfigLoaded(for brandName: String) -> Bool {
        config != nil && initializedBrandName == brandName
    }

    func setConsent(granted: Bool) {
        consentGranted = granted
        if !granted {
            dismiss()
            payload = nil
        }
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
            payload: payload
        ) else {
            callbacks.onError?("No eligible rewards available for current context.")
            hidePopupOverlay()
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
        closeButtonShowsDismiss = false
        isMinimized = false
        isPresented = true
        showPopupOverlay()
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
            at: date,
            suppressionRules: config?.suppressionRules
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
        logError(message)
        callbacks.onError?(message)
        hidePopupOverlay()
        hideMinimizedBadgeOverlay()
        isMinimized = false
        closeButtonShowsDismiss = false
        isPresented = false
        state = .hidden
        resetPresentationTracking()
    }

    private func showPopupOverlay() {
#if canImport(UIKit)
        DelightPopupOverlay.show()
#endif
    }

    private func hidePopupOverlay() {
#if canImport(UIKit)
        DelightPopupOverlay.hide()
#endif
    }

    private func minimizedBadgeTheme() -> DelightPopupTheme {
        if case .ready(_, let theme, _) = state {
            return theme
        }
        return DelightPopupTheme.fromBrandTheme(config?.popup?.theme)
    }

    private func showMinimizedBadgeOverlay() {
#if canImport(UIKit)
        DelightMinimizedBadgeOverlay.show(theme: minimizedBadgeTheme()) { [weak self] in
            self?.expandFromMinimized()
        }
#endif
    }

    private func hideMinimizedBadgeOverlay() {
#if canImport(UIKit)
        DelightMinimizedBadgeOverlay.hide()
#endif
    }

    private func triggerBackendImpressionTracking() {
        guard
            consentGranted,
            let config,
            let partnerId = config.partnerId, !partnerId.isEmpty,
            let rewardId = currentRewardId, !rewardId.isEmpty
        else { return }

        let request = DelightTrackingService.RewardImpressionRequest(
            hostPartnerId: partnerId,
            rewardId: rewardId,
            impressionCount: 1
        )

        Task.detached {
            do {
                try await DelightTrackingService.trackRewardImpression(
                    request: request,
                    apiBaseURLString: config.apiUrl,
                    partnerIdHeader: partnerId
                )
            } catch {
                let message = "Failed to track reward impression: \(error.localizedDescription)"
                await MainActor.run {
                    self.logError(message)
                    self.callbacks.onError?(message)
                }
            }
        }
    }

    private func triggerBackendRewardClaimTracking(rewardId: String?) {
        guard
            consentGranted,
            let config,
            let partnerId = config.partnerId, !partnerId.isEmpty,
            let brandName = initializedBrandName, !brandName.isEmpty,
            let rewardId, !rewardId.isEmpty,
            let payload
        else { return }

        let orderId = {
            if let existingOrderId = payload.orderId, !existingOrderId.isEmpty {
                return existingOrderId
            }
            return makeFallbackOrderId(brandName: brandName)
        }()

        let request = DelightTrackingService.RewardClaimRequest(
            partnerId: partnerId,
            brandName: brandName,
            customerEmail: payload.email ?? "",
            orderReward: rewardId,
            orderId: orderId
        )

        Task.detached {
            await self.runWithBackgroundExecution {
                do {
                    try await DelightTrackingService.trackRewardClaim(
                        request: request,
                        apiBaseURLString: config.apiUrl,
                        partnerIdHeader: partnerId
                    )
                } catch {
                    let message = "Failed to track reward claim: \(error.localizedDescription)"
                    await MainActor.run {
                        self.logError(message)
                        self.callbacks.onError?(message)
                    }
                }
            }
        }
    }

    private func makeFallbackOrderId(brandName: String) -> String {
        let brandPrefix = brandName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "-")
        let timestampMs = Int(Date().timeIntervalSince1970 * 1000)
        return "\(brandPrefix)-\(timestampMs)"
    }

    private func logError(_ message: String) {
#if DEBUG
        print("Delight SDK Error:", message)
#endif
    }

    private func runWithBackgroundExecution(
        operation: @escaping @Sendable () async -> Void
    ) async {
#if canImport(UIKit)
        let taskName = "DelightRewardClaimTracking-\(UUID().uuidString)"
        var taskId = UIBackgroundTaskIdentifier.invalid
        var operationTask: Task<Void, Never>?

        taskId = UIApplication.shared.beginBackgroundTask(withName: taskName) {
            operationTask?.cancel()
            if taskId != .invalid {
                UIApplication.shared.endBackgroundTask(taskId)
                taskId = .invalid
            }
        }

        operationTask = Task {
            await operation()
        }
        await operationTask?.value

        if taskId != .invalid {
            UIApplication.shared.endBackgroundTask(taskId)
            taskId = .invalid
        }
#else
        await operation()
#endif
    }
}
