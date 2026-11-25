import Foundation

public struct DelightRequestPayload {
    public let orderId: String?
    public let email: String?
    public let userToken: String?
    public let firstName: String?
    public let lastName: String?
    public let ticketTypes: [String]?

    public init(
        orderId: String? = nil,
        email: String? = nil,
        userToken: String? = nil,
        firstName: String? = nil,
        lastName: String? = nil,
        ticketTypes: [String]? = nil
    ) {
        self.orderId = orderId
        self.email = email
        self.userToken = userToken
        self.firstName = firstName
        self.lastName = lastName
        self.ticketTypes = ticketTypes
    }
}

public struct DelightCallbacks {
    public var onImpression: ((String?) -> Void)?
    public var onPrimaryClick: ((String?) -> Void)?
    public var onDismiss: (() -> Void)?
    public var onError: ((String) -> Void)?
    /// GWR: overlay minimised. Passes the reward that was on screen.
    public var onOverlayMinimised: ((String?) -> Void)?
    /// GWR: gift icon tapped. Passes the reward the icon will reopen.
    public var onGiftIconTapped: ((String?) -> Void)?

    public init(
        onImpression: ((String?) -> Void)? = nil,
        onPrimaryClick: ((String?) -> Void)? = nil,
        onDismiss: (() -> Void)? = nil,
        onError: ((String) -> Void)? = nil,
        onOverlayMinimised: ((String?) -> Void)? = nil,
        onGiftIconTapped: ((String?) -> Void)? = nil
    ) {
        self.onImpression = onImpression
        self.onPrimaryClick = onPrimaryClick
        self.onDismiss = onDismiss
        self.onError = onError
        self.onOverlayMinimised = onOverlayMinimised
        self.onGiftIconTapped = onGiftIconTapped
    }
}

