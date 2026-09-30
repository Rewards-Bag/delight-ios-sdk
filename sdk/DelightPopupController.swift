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
    /// Survives minimize/reopen because the overlay view (and its `@State`) is destroyed.
    @Published var carouselRewardIndex = 0
    @Published var claimedRewardIds = Set<String>()

    private var currentRewardId: String?
    private var didClickCurrentReward = false
    private var didRecordIgnoreForCurrentPresentation = false
    private var didCommitVisibleImpression = false
    private var impressedRewardIdsThisPresentation = Set<String>()
    private(set) var initializedBrandName: String?
    private var presentationEpoch = 0
    private var lifecycleCancellables = Set<AnyCancellable>()
    private var didInstallApplicationLifecycleObservers = false
    private var configLoadInProgress = false
    private var configLoadTargetBrand: String?
    private var configLoadToken = 0

    private init() {
        installApplicationLifecycleObserversIfNeeded()
    }

#if canImport(UIKit)
    private func installApplicationLifecycleObserversIfNeeded() {
        guard !didInstallApplicationLifecycleObservers else { return }
        didInstallApplicationLifecycleObservers = true

        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.handleEnterBackgroundForLifecycle()
            }
            .store(in: &lifecycleCancellables)

        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.handleEnterForegroundForLifecycle()
            }
            .store(in: &lifecycleCancellables)
    }
#else
    private func installApplicationLifecycleObserversIfNeeded() {}
#endif

    func show(payload: DelightRequestPayload, callbacks: DelightCallbacks) {
        guard !DelightSessionGuard.shouldNoOpPublicAPI else { return }

        presentationEpoch &+= 1
        let epoch = presentationEpoch

        self.payload = payload
        self.callbacks = callbacks
        hideMinimizedBadgeOverlay()
        hidePopupOverlay()
        isMinimized = false
        closeButtonShowsDismiss = false
        guard consentGranted else {
            abandonPresentationSilently()
            return
        }
        self.state = .loading
        resetPresentationTracking()
        Task { await self.fetchConfigAndBuildPopup(expectedEpoch: epoch) }
    }

    func show() {
        isPresented = true
        if case .ready = state {
            return
        }
        state = .idle
    }

    func dismissSafely() {
        presentationEpoch &+= 1
        DelightFailSafe.run {
            performDismiss()
        } onFailure: { error in
            DelightFailSafeLog.sdkError("Dismiss failed: \(error.localizedDescription)")
            self.abandonPresentationSilently()
        }
    }

    private func performDismiss() {
        recordIgnoreIfNoClick()
        hidePopupOverlay()
        hideMinimizedBadgeOverlay()
        isMinimized = false
        closeButtonShowsDismiss = false
        isPresented = false
        state = .hidden
        DelightPopupSessionStore.clear()
        let dismissCallback = callbacks.onDismiss
        resetPresentationTracking()
        DelightHostCallbacks.invokeDismiss(dismissCallback)
    }

    func dismiss() {
        dismissSafely()
    }

    func abandonPresentationSilently() {
        presentationEpoch &+= 1
        hidePopupOverlay()
        hideMinimizedBadgeOverlay()
        isMinimized = false
        closeButtonShowsDismiss = false
        isPresented = false
        state = .hidden
        DelightPopupSessionStore.clear()
        resetPresentationTracking()
    }

    func tearDownAfterRenderFailure() {
        DelightFailSafeLog.sdkError("Render path failed; tearing down popup")
        abandonPresentationSilently()
    }

    /// Collapses the popup to a floating present icon without recording an ignore.
    func minimize() {
        guard case .ready(let config, _, _) = state, config.isPresentIconEnabled else { return }
        hidePopupOverlay()
        isMinimized = true
        isPresented = false
        showMinimizedBadgeOverlay()
        persistSessionSnapshot()
    }

    /// Reopens the reward popup from the minimized present icon (close button becomes X).
    func expandFromMinimized() {
        guard case .ready(let config, _, _) = state, config.isPresentIconEnabled else { return }
        hideMinimizedBadgeOverlay()
        closeButtonShowsDismiss = true
        isMinimized = false
        isPresented = true
        showPopupOverlay()
        persistSessionSnapshot()
    }

    func markRewardBecameVisible(at index: Int, in config: DelightConfigDTO) {
        let rewards = config.resolvedRewards
        guard !rewards.isEmpty else { return }
        let clampedIndex = min(max(index, 0), rewards.count - 1)
        markRewardBecameVisible(rewards[clampedIndex].id)
    }

    func markRewardBecameVisible(_ rewardId: String?) {
        guard let rewardId, !rewardId.isEmpty else { return }
        guard !impressedRewardIdsThisPresentation.contains(rewardId) else { return }

        impressedRewardIdsThisPresentation.insert(rewardId)
        currentRewardId = rewardId
        commitVisibleImpressionIfNeeded(at: Date())
        triggerBackendImpressionTracking(rewardId: rewardId)
        DelightHostCallbacks.invokeImpression(callbacks.onImpression, rewardId: rewardId)
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

    func clearInitializationError() {}

    func setInitializedBrandName(_ value: String?) {
        initializedBrandName = value
    }

    func beginConfigLoad(for brandName: String) -> Int {
        configLoadInProgress = true
        configLoadTargetBrand = brandName
        return configLoadToken
    }

    func endConfigLoad() {
        configLoadInProgress = false
        configLoadTargetBrand = nil
    }

    func shouldApplyConfigLoad(token: Int) -> Bool {
        token == configLoadToken
    }

    func prepareForBrandSwitch() {
        configLoadToken &+= 1
        endConfigLoad()
        dismissSafely()
        config = nil
        clearInitializationError()
        initializedBrandName = nil
        DelightPopupSessionStore.clear()
    }

    func resetForTesting() {
        abandonPresentationSilently()
        config = nil
        payload = nil
        callbacks = .init()
        initializedBrandName = nil
        DelightPopupSessionStore.clear()
        state = .idle
        presentationEpoch = 0
        configLoadToken = 0
        endConfigLoad()
    }

    func persistSessionSnapshot() {
        guard
            let payload,
            let orderId = payload.orderId?.trimmingCharacters(in: .whitespacesAndNewlines),
            !orderId.isEmpty,
            let brandName = initializedBrandName,
            !brandName.isEmpty
        else {
            DelightPopupSessionStore.clear()
            return
        }

        guard case .ready(let config, _, _) = state else {
            if isMinimized {
                DelightPopupSessionStore.save(
                    DelightPopupSessionStore.Snapshot(
                        orderId: orderId,
                        brandName: brandName,
                        carouselRewardIndex: carouselRewardIndex,
                        claimedRewardIds: Array(claimedRewardIds),
                        isMinimized: true,
                        impressedRewardIds: Array(impressedRewardIdsThisPresentation)
                    )
                )
            }
            return
        }

        DelightPopupSessionStore.save(
            DelightPopupSessionStore.Snapshot(
                orderId: orderId,
                brandName: brandName,
                carouselRewardIndex: carouselRewardIndex,
                claimedRewardIds: Array(claimedRewardIds),
                isMinimized: isMinimized,
                impressedRewardIds: Array(impressedRewardIdsThisPresentation)
            )
        )
        _ = config
    }

    @discardableResult
    func restoreSessionSnapshotIfMatching(orderId: String?, brandName: String?) -> Bool {
        guard
            let snapshot = DelightPopupSessionStore.load(),
            let orderId = orderId?.trimmingCharacters(in: .whitespacesAndNewlines),
            !orderId.isEmpty,
            orderId == snapshot.orderId,
            brandName == snapshot.brandName
        else {
            return false
        }

        carouselRewardIndex = snapshot.carouselRewardIndex
        claimedRewardIds = Set(snapshot.claimedRewardIds)
        impressedRewardIdsThisPresentation = Set(snapshot.impressedRewardIds)
        isMinimized = snapshot.isMinimized
        closeButtonShowsDismiss = snapshot.isMinimized || !(config?.isPresentIconEnabled ?? true)
        return true
    }

    func handleEnterBackgroundForLifecycle() {
        persistSessionSnapshot()
    }

    func handleEnterForegroundForLifecycle() {
        guard case .ready = state else { return }
        if isMinimized {
            showMinimizedBadgeOverlay()
        } else if isPresented {
            showPopupOverlay()
        }
    }

    func handleInterfaceRotationForLifecycle() {
        guard case .ready = state else { return }
        persistSessionSnapshot()
        if isPresented {
            showPopupOverlay()
        } else if isMinimized {
            showMinimizedBadgeOverlay()
        }
    }

    func buildPopupFromCurrentConfig() async {
        presentationEpoch &+= 1
        let epoch = presentationEpoch
        await fetchConfigAndBuildPopup(expectedEpoch: epoch)
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

    private func fetchConfigAndBuildPopup(expectedEpoch: Int) async {
        guard expectedEpoch == presentationEpoch else { return }
        guard !DelightSessionGuard.shouldNoOpPublicAPI else {
            abandonPresentationSilently()
            return
        }

        await DelightFailSafe.runAsync {
            try await self.buildPopupIfStillCurrent(expectedEpoch: expectedEpoch)
        } onFailure: { error in
            DelightFailSafeLog.sdkError("Popup build failed: \(error.localizedDescription)")
            self.abandonPresentationSilently()
        }
    }

    private func buildPopupIfStillCurrent(expectedEpoch: Int) async throws {
        guard expectedEpoch == presentationEpoch else { return }
        guard let payload else {
            abandonPresentationSilently()
            return
        }

        guard let resolvedConfig = config else {
            if configLoadInProgress {
                DelightFailSafeLog.debug("Popup show skipped: config load in progress")
            } else {
                DelightFailSafeLog.debug("Popup show skipped: SDK not initialized for a brand")
            }
            abandonPresentationSilently()
            return
        }

        if configLoadInProgress {
            abandonPresentationSilently()
            return
        }

        guard expectedEpoch == presentationEpoch else { return }

        switch DelightConfigValidator.validateForPresentation(resolvedConfig) {
        case .success:
            break
        case .failure(let reason):
            DelightFailSafeLog.debug("Config not presentable: \(reason)")
            abandonPresentationSilently()
            return
        }

        guard let selectedConfig = DelightRewardSelectionService.selectConfig(
            from: resolvedConfig,
            payload: payload
        ) else {
            abandonPresentationSilently()
            return
        }

        switch DelightConfigValidator.validateForPresentation(selectedConfig) {
        case .success:
            break
        case .failure:
            abandonPresentationSilently()
            return
        }

        guard expectedEpoch == presentationEpoch else { return }

        let selectedRewardId = selectedConfig.popup?.rewards?.first?.id
        let theme = DelightPopupTheme.fromBrandTheme(selectedConfig.popup?.theme)
        state = .ready(selectedConfig, theme, selectedRewardId)
        currentRewardId = selectedRewardId
        didClickCurrentReward = false
        closeButtonShowsDismiss = !selectedConfig.isPresentIconEnabled
        isMinimized = false
        isPresented = true

        if restoreSessionSnapshotIfMatching(
            orderId: payload.orderId,
            brandName: initializedBrandName
        ), isMinimized {
            isPresented = false
            showMinimizedBadgeOverlay()
            persistSessionSnapshot()
            return
        }

        showPopupOverlay()
        persistSessionSnapshot()
    }

    func closeButtonAction(for config: DelightConfigDTO) -> DelightPopupCloseButtonAction {
        guard config.isPresentIconEnabled else { return .dismiss }
        return closeButtonShowsDismiss ? .dismiss : .minimize
    }

    func shouldMinimizeOnCloseTap(for config: DelightConfigDTO) -> Bool {
        config.isPresentIconEnabled && !closeButtonShowsDismiss
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
        impressedRewardIdsThisPresentation = []
        carouselRewardIndex = 0
        claimedRewardIds = []
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
        guard isPresentIconEnabledForCurrentPresentation else { return }
        DelightMinimizedBadgeOverlay.show(theme: minimizedBadgeTheme()) { [weak self] in
            self?.expandFromMinimized()
        }
#endif
    }

    private var isPresentIconEnabledForCurrentPresentation: Bool {
        if case .ready(let config, _, _) = state {
            return config.isPresentIconEnabled
        }
        return config?.isPresentIconEnabled ?? true
    }

    private func hideMinimizedBadgeOverlay() {
#if canImport(UIKit)
        DelightMinimizedBadgeOverlay.hide()
#endif
    }

    private func triggerBackendImpressionTracking(rewardId: String) {
        guard
            consentGranted,
            let config,
            let partnerId = config.partnerId, !partnerId.isEmpty,
            !rewardId.isEmpty
        else { return }

        let request = DelightTrackingService.RewardImpressionRequest(
            hostPartnerId: partnerId,
            rewardId: rewardId,
            impressionCount: 1
        )

        let apiUrl = config.apiUrl
        Task.detached {
            do {
                try await DelightTrackingService.trackRewardImpression(
                    request: request,
                    apiBaseURLString: apiUrl,
                    partnerIdHeader: partnerId
                )
            } catch {
                let message = "Failed to track reward impression: \(error.localizedDescription)"
                DelightFailSafeLog.debug(message)
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

        let apiUrl = config.apiUrl
        Task { [weak self] in
            guard let self else { return }
            await self.runWithBackgroundExecution {
                do {
                    try await DelightTrackingService.trackRewardClaim(
                        request: request,
                        apiBaseURLString: apiUrl,
                        partnerIdHeader: partnerId
                    )
                } catch {
                    let message = "Failed to track reward claim: \(error.localizedDescription)"
                    DelightFailSafeLog.debug(message)
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
