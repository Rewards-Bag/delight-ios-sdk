import Foundation

@MainActor
public enum Delight {
    public static func initialize(
        brandName: String,
        cdnBaseURL: URL = URL(string: "https://cdn.rewardsbag.com")!
    ) async throws {
        let config = try await DelightConfigService.fetchConfig(
            brandName: brandName,
            cdnBaseURL: cdnBaseURL
        )
        DelightPopupController.shared.config = config
    }

    public static func showReward(
        _ payload: DelightRequestPayload,
        callbacks: DelightCallbacks = .init()
    ) {
        DelightPopupController.shared.show(payload: payload, callbacks: callbacks)
    }

    public static func dismiss() {
        DelightPopupController.shared.dismiss()
    }
}
