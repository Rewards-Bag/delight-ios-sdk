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

