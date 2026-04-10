import Foundation

struct DelightDecisionResponse: Decodable {
    let show: Bool
    let templateId: String
    let content: DelightContentDTO
    let theme: DelightThemeDTO?
    let tracking: DelightTrackingDTO?
}

struct DelightContentDTO: Decodable {
    let title: String
    let subtitle: String?
    let imageUrl: String?
    let primaryCta: String?
    let secondaryCta: String?
    let legalUrl: String?
    let rewardId: String?
    let deeplink: String?
}

struct DelightThemeDTO: Decodable {
    let primaryHex: String?
    let onPrimaryHex: String?
    let surfaceHex: String?
    let radiusDp: Double?
    let elevationDp: Double?
    let fontScale: Double?
}

struct DelightTrackingDTO: Decodable {
    let impressionToken: String?
}

struct DelightDecisionRequest: Encodable {
    let orderId: String
    let email: String
    let firstName: String
    let lastName: String
}
