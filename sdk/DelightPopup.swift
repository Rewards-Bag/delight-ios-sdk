import Foundation

@MainActor
public enum Delight {
    private static let sdkUserTokenDefaultsKey = "delight.sdk.local-user-token"
    private static let defaultCDNBaseURL = URL(string: "https://cdn.rewardsbag.com")
        ?? URL(fileURLWithPath: "/")

    /// - Parameters:
    ///   - useBundledConfig: When `true`, loads `config.json` from the app bundle (e.g. `sdk/config.json` copied into the target) and skips the CDN. Use for local testing.
    ///   - ignoreDailyCooldownHours: When `true`, treats `dailyCooldownHours` as 0 so the second daily reward slot is not blocked by the cooldown.
    public static func initialize(
        brandName: String,
        locale: String = "en",
        cdnBaseURL: URL? = nil,
        useBundledConfig: Bool = false,
        ignoreDailyCooldownHours: Bool = false,
        consentGranted: Bool = true
    ) async {
        guard !DelightSessionGuard.shouldNoOpPublicAPI else { return }

        DelightRewardSelectionService.ignoreDailyCooldownHours = ignoreDailyCooldownHours
        let controller = DelightPopupController.shared
        controller.setConsent(granted: consentGranted)
        if consentGranted {
            _ = localSDKUserToken()
        }

        if let loadedBrand = controller.initializedBrandName, loadedBrand != brandName {
            controller.prepareForBrandSwitch()
        }

        if controller.isConfigLoaded(for: brandName) {
            return
        }

        let configLoadToken = controller.beginConfigLoad(for: brandName)
        defer { controller.endConfigLoad() }

        let resolvedCDN = cdnBaseURL ?? defaultCDNBaseURL

        do {
            let config: DelightConfigDTO
            if useBundledConfig {
                config = try DelightConfigService.loadBundledConfig()
            } else {
                config = try await DelightConfigService.fetchConfig(
                    brandName: brandName,
                    cdnBaseURL: resolvedCDN
                )
            }
            guard controller.shouldApplyConfigLoad(token: configLoadToken) else {
                return
            }
            let resolved = configWithResolvedLocale(
                config,
                explicitLocale: locale,
                brandName: brandName
            )
            switch DelightConfigValidator.validateForPresentation(resolved) {
            case .success:
                controller.config = resolved
            case .failure:
                controller.config = safeEmptyConfig(brandName: brandName)
            }
            controller.setInitializedBrandName(brandName)
            controller.clearInitializationError()
        } catch {
            guard controller.shouldApplyConfigLoad(token: configLoadToken) else {
                return
            }
            DelightSessionGuard.disableAfterInitializationFailure(error.localizedDescription)
            controller.config = nil
            controller.setInitializedBrandName(nil)
            controller.clearInitializationError()
            controller.abandonPresentationSilently()
        }
    }

    public static func setConsent(granted: Bool) {
        guard !DelightSessionGuard.shouldNoOpPublicAPI else { return }
        DelightPopupController.shared.setConsent(granted: granted)
        if granted {
            return
        }
        clearLocalData()
    }

    public static func clearLocalData() {
        guard !DelightSessionGuard.shouldNoOpPublicAPI else { return }
        UserDefaults.standard.removeObject(forKey: sdkUserTokenDefaultsKey)
        DelightRewardSelectionService.clearLocalData()
    }

    /// Clears today's daily reward slots for all users, mimicking a GMT midnight rollover.
    /// Use for QA to re-test first/second daily rewards without waiting until midnight.
    /// Fatigue, click suppression, and monthly impression history are preserved.
    public static func resetDailySuppressionState() {
        guard !DelightSessionGuard.shouldNoOpPublicAPI else { return }
        DelightRewardSelectionService.resetDailySuppressionState()
    }

    public static func showRewardPopup(
        _ payload: DelightRequestPayload,
        callbacks: DelightCallbacks = .init()
    ) {
        guard !DelightSessionGuard.shouldNoOpPublicAPI else { return }
        DelightPopupController.shared.show(
            payload: payloadWithResolvedUserToken(payload),
            callbacks: callbacks
        )
    }

    @available(*, deprecated, renamed: "showRewardPopup(_:callbacks:)")
    public static func showReward(
        _ payload: DelightRequestPayload,
        callbacks: DelightCallbacks = .init()
    ) {
        showRewardPopup(payload, callbacks: callbacks)
    }

    public static func dismiss() {
        guard !DelightSessionGuard.shouldNoOpPublicAPI else { return }
        DelightPopupController.shared.dismissSafely()
    }

    @available(*, deprecated, message: "Not required; the SDK observes UIApplication background/foreground automatically.")
    public static func handleApplicationDidEnterBackground() {
        guard !DelightSessionGuard.shouldNoOpPublicAPI else { return }
        DelightPopupController.shared.handleEnterBackgroundForLifecycle()
    }

    @available(*, deprecated, message: "Not required; the SDK observes UIApplication background/foreground automatically.")
    public static func handleApplicationWillEnterForeground() {
        guard !DelightSessionGuard.shouldNoOpPublicAPI else { return }
        DelightPopupController.shared.handleEnterForegroundForLifecycle()
    }

    /// Optional: forward rotation if overlays misalign on a specific host; most apps can omit this.
    public static func handleInterfaceOrientationChange() {
        guard !DelightSessionGuard.shouldNoOpPublicAPI else { return }
        DelightPopupController.shared.handleInterfaceRotationForLifecycle()
    }

    /// Resets SDK popup state for unit tests (does not clear suppression history). Not for host apps.
    public static func resetPopupControllerForTesting() {
        DelightSessionGuard.resetForTesting()
        DelightPopupController.shared.resetForTesting()
    }

    /// Loads config directly for unit tests (skips CDN).
    static func loadConfigForTesting(
        brandName: String,
        locale: String = "en",
        config: DelightConfigDTO
    ) {
        DelightSessionGuard.resetForTesting()
        let controller = DelightPopupController.shared
        controller.config = DelightConfigDTO(
            partnerId: config.partnerId,
            partnerLogo: config.partnerLogo,
            hostDisplayName: config.hostDisplayName,
            apiUrl: config.apiUrl,
            language: locale,
            popup: config.popup,
            suppressionRules: config.suppressionRules,
            brandName: brandName
        )
        controller.setInitializedBrandName(brandName)
        controller.clearInitializationError()
    }

    private static func payloadWithResolvedUserToken(_ payload: DelightRequestPayload) -> DelightRequestPayload {
        guard DelightPopupController.shared.consentGranted else {
            return DelightRequestPayload(
                orderId: payload.orderId,
                email: payload.email,
                userToken: nil,
                firstName: payload.firstName,
                lastName: payload.lastName,
                ticketTypes: payload.ticketTypes
            )
        }
        let existingToken = payload.userToken?.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedToken: String
        if let existingToken, !existingToken.isEmpty {
            resolvedToken = existingToken
        } else {
            resolvedToken = localSDKUserToken()
        }
        return DelightRequestPayload(
            orderId: payload.orderId,
            email: payload.email,
            userToken: resolvedToken,
            firstName: payload.firstName,
            lastName: payload.lastName,
            ticketTypes: payload.ticketTypes
        )
    }

    private static func localSDKUserToken() -> String {
        let defaults = UserDefaults.standard
        if let value = defaults.string(forKey: sdkUserTokenDefaultsKey),
           !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return value
        }
        let created = UUID().uuidString.lowercased()
        defaults.set(created, forKey: sdkUserTokenDefaultsKey)
        return created
    }

    private static func safeEmptyConfig(brandName: String? = nil) -> DelightConfigDTO {
        DelightConfigDTO(
            partnerId: nil,
            partnerLogo: nil,
            hostDisplayName: nil,
            apiUrl: nil,
            language: "en",
            popup: DelightPopupSectionDTO(
                enabled: false,
                defaultLocale: "en",
                locales: nil,
                theme: nil,
                rewards: [],
                enablePresentIcon: nil
            ),
            suppressionRules: nil,
            brandName: brandName
        )
    }

    private static func configWithResolvedLocale(
        _ config: DelightConfigDTO,
        explicitLocale: String,
        brandName: String
    ) -> DelightConfigDTO {
        let resolvedLocale = normalizedLocaleCode(explicitLocale)
            ?? "en"
        return DelightConfigDTO(
            partnerId: config.partnerId,
            partnerLogo: config.partnerLogo,
            hostDisplayName: config.hostDisplayName,
            apiUrl: config.apiUrl,
            language: resolvedLocale,
            popup: config.popup,
            suppressionRules: config.suppressionRules,
            brandName: brandName
        )
    }

    private static func normalizedLocaleCode(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let lowered = trimmed.lowercased().replacingOccurrences(of: "_", with: "-")
        if let primary = lowered.split(separator: "-").first, !primary.isEmpty {
            return String(primary)
        }
        return lowered
    }

}
