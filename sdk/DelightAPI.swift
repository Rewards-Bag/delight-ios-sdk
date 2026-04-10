import Foundation

public struct DelightRequestPayload {
    public let orderId: String
    public let email: String
    public let firstName: String
    public let lastName: String

    public init(orderId: String, email: String, firstName: String, lastName: String) {
        self.orderId = orderId
        self.email = email
        self.firstName = firstName
        self.lastName = lastName
    }
}

public struct DelightConfiguration {
    public let apiBaseURL: URL
    public let clientId: String
    public let apiKey: String

    public init(apiBaseURL: URL, clientId: String, apiKey: String) {
        self.apiBaseURL = apiBaseURL
        self.clientId = clientId
        self.apiKey = apiKey
    }
}

public struct DelightCallbacks {
    public var onImpression: ((String?) -> Void)?
    public var onPrimaryClick: ((String?) -> Void)?
    public var onDismiss: (() -> Void)?

    public init(
        onImpression: ((String?) -> Void)? = nil,
        onPrimaryClick: ((String?) -> Void)? = nil,
        onDismiss: (() -> Void)? = nil
    ) {
        self.onImpression = onImpression
        self.onPrimaryClick = onPrimaryClick
        self.onDismiss = onDismiss
    }
}

@MainActor
public enum Delight {
    public static func configure(_ configuration: DelightConfiguration) {
        DelightPopupController.shared.configuration = configuration
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
