import Foundation

@MainActor
public enum Delight {
    private static let sdkUserTokenDefaultsKey = "delight.sdk.local-user-token"

    /// - Parameters:
    ///   - useBundledConfig: When `true`, loads `config.json` from the app bundle (e.g. `sdk/config.json` copied into the target) and skips the CDN. Use for local testing.
    ///   - ignoreDailyCooldownHours: When `true`, treats `dailyCooldownHours` as 0 so the second daily reward slot is not blocked by the cooldown.
    public static func initialize(
        brandName: String,
        locale: String = "en",
        cdnBaseURL: URL = URL(string: "https://cdn.rewardsbag.com")!,
        useBundledConfig: Bool = false,
        ignoreDailyCooldownHours: Bool = false,
        consentGranted: Bool = true
    ) async throws {
        DelightRewardSelectionService.ignoreDailyCooldownHours = ignoreDailyCooldownHours
        let controller = DelightPopupController.shared
        controller.setConsent(granted: consentGranted)
        if consentGranted {
            _ = localSDKUserToken()
        }
        if controller.isConfigLoaded(for: brandName) {
            return
        }
        do {
            let config: DelightConfigDTO
            if useBundledConfig {
                config = try DelightConfigService.loadBundledConfig()
            } else {
                config = try await DelightConfigService.fetchConfig(
                    brandName: brandName,
                    cdnBaseURL: cdnBaseURL
                )
            }
            DelightPopupController.shared.config = configWithResolvedLocale(
                config,
                explicitLocale: locale
            )
            controller.setInitializedBrandName(brandName)
            controller.clearInitializationError()
        } catch {
            // Crash isolation: never throw initialization failures into host apps.
            let message = "Failed to initialize Delight SDK config: \(error.localizedDescription)"
            logError(message)
            controller.config = safeEmptyConfig()
            controller.setInitializedBrandName(brandName)
            controller.reportInitializationError(message)
        }
    }

    public static func setConsent(granted: Bool) {
        DelightPopupController.shared.setConsent(granted: granted)
        if granted {
            return
        }
        clearLocalData()
    }

    public static func clearLocalData() {
        UserDefaults.standard.removeObject(forKey: sdkUserTokenDefaultsKey)
        DelightRewardSelectionService.clearLocalData()
    }

    /// Clears today's daily reward slots for all users, mimicking a GMT midnight rollover.
    /// Use for QA to re-test first/second daily rewards without waiting until midnight.
    /// Fatigue, click suppression, and monthly impression history are preserved.
    public static func resetDailySuppressionState() {
        DelightRewardSelectionService.resetDailySuppressionState()
    }

    public static func showRewardPopup(
        _ payload: DelightRequestPayload,
        callbacks: DelightCallbacks = .init()
    ) {
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
        DelightPopupController.shared.dismiss()
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
        let resolvedToken = (existingToken?.isEmpty == false) ? existingToken! : localSDKUserToken()
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

    private static func safeEmptyConfig() -> DelightConfigDTO {
        DelightConfigDTO(
            partnerId: nil,
            partnerLogo: nil,
            apiUrl: nil,
            language: "en",
            popup: DelightPopupSectionDTO(
                enabled: false,
                defaultLocale: "en",
                locales: nil,
                theme: nil,
                rewards: []
            ),
            suppressionRules: nil
        )
    }

    private static func configWithResolvedLocale(
        _ config: DelightConfigDTO,
        explicitLocale: String
    ) -> DelightConfigDTO {
        let resolvedLocale = normalizedLocaleCode(explicitLocale)
            ?? "en"
        return DelightConfigDTO(
            partnerId: config.partnerId,
            partnerLogo: config.partnerLogo,
            apiUrl: config.apiUrl,
            language: resolvedLocale,
            popup: config.popup,
            suppressionRules: config.suppressionRules
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

    private static func logError(_ message: String) {
#if DEBUG
        print("Delight SDK Error:", message)
#endif
    }

}
