import Foundation

@MainActor
public enum Delight {
    private static let sdkUserTokenDefaultsKey = "delight.sdk.local-user-token"

    /// - Parameters:
    ///   - useBundledConfig: When `true`, loads `config.json` from the app bundle (e.g. `sdk/config.json` copied into the target) and skips the CDN. Use for local testing.
    ///   - ignoreLocalRulesForTesting: When `true`, skips the monthly impression cap and 24h cooldown (QA only).
    ///   - ignoreCooldownForLocalDevelopment: When `true`, skips **only** the 24h cooldown so you can trigger another popup on every run; monthly cap and per-reward suppression still apply. Use for local development, not production.
    public static func initialize(
        brandName: String,
        cdnBaseURL: URL = URL(string: "https://cdn.rewardsbag.com")!,
        useBundledConfig: Bool = false,
        ignoreLocalRulesForTesting: Bool = false,
        ignoreCooldownForLocalDevelopment: Bool = false
    ) async throws {
        _ = localSDKUserToken()
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
            DelightPopupController.shared.config = config
            DelightPopupController.shared.setInitializedBrandName(brandName)
            DelightPopupController.shared.clearInitializationError()
        } catch {
            // Crash isolation: never throw initialization failures into host apps.
            let message = "Failed to initialize Delight SDK config: \(error.localizedDescription)"
            logError(message)
            DelightPopupController.shared.config = safeEmptyConfig()
            DelightPopupController.shared.setInitializedBrandName(brandName)
            DelightPopupController.shared.reportInitializationError(message)
        }
        DelightPopupController.shared.ignoreLocalRulesForTesting = ignoreLocalRulesForTesting
        DelightPopupController.shared.ignoreCooldownForLocalDevelopment = ignoreCooldownForLocalDevelopment
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
            )
        )
    }

    private static func logError(_ message: String) {
#if DEBUG
        print("Delight SDK Error:", message)
#endif
    }

}
