import Foundation

@MainActor
public enum Delight {
    private static let sdkUserTokenDefaultsKey = "delight.sdk.local-user-token"

    /// - Parameters:
    ///   - useBundledConfig: When `true`, loads `config.json` from the app bundle (e.g. `sdk/config.json` copied into the target) and skips the CDN. Use for local testing.
    public static func initialize(
        brandName: String,
        cdnBaseURL: URL = URL(string: "https://cdn.rewardsbag.com")!,
        useBundledConfig: Bool = false,
        ignoreLocalRulesForTesting: Bool = false
    ) async throws {
        _ = localSDKUserToken()
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
        DelightPopupController.shared.ignoreLocalRulesForTesting = ignoreLocalRulesForTesting
    }

    public static func showReward(
        _ payload: DelightRequestPayload,
        callbacks: DelightCallbacks = .init()
    ) {
        DelightPopupController.shared.show(
            payload: payloadWithResolvedUserToken(payload),
            callbacks: callbacks
        )
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
}
