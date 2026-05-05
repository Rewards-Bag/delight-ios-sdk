import Combine
import Foundation
#if canImport(UIKit)
import UIKit
#endif

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
    private var initializedBrandName: String?

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
        logError(message)
        callbacks.onError?(message)
        isPresented = false
        state = .hidden
        resetPresentationTracking()
    }

    private func triggerBackendImpressionTracking() {
        guard
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
