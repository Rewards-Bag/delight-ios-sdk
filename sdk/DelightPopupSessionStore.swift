import Foundation

/// Persists in-flight popup session across backgrounding or process termination.
enum DelightPopupSessionStore {
    private static let defaultsKey = "delight.sdk.popup-session.v1"

    struct Snapshot: Codable, Equatable {
        var orderId: String
        var brandName: String
        var carouselRewardIndex: Int
        var claimedRewardIds: [String]
        var isMinimized: Bool
        var impressedRewardIds: [String]
    }

    static func save(_ snapshot: Snapshot?) {
        let defaults = UserDefaults.standard
        guard let snapshot else {
            defaults.removeObject(forKey: defaultsKey)
            return
        }
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: defaultsKey)
    }

    static func load() -> Snapshot? {
        guard
            let data = UserDefaults.standard.data(forKey: defaultsKey),
            let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data)
        else {
            return nil
        }
        return snapshot
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: defaultsKey)
    }

    private static let exhaustedKey = "delight.sdk.popup-exhausted.v1"

    static func markRewardsExhausted(orderId: String, brandName: String) {
        let token = exhaustionToken(orderId: orderId, brandName: brandName)
        guard !token.isEmpty else { return }
        var tokens = exhaustedTokens()
        tokens.insert(token)
        UserDefaults.standard.set(Array(tokens), forKey: exhaustedKey)
    }

    static func areRewardsExhausted(orderId: String?, brandName: String?) -> Bool {
        let token = exhaustionToken(orderId: orderId ?? "", brandName: brandName ?? "")
        guard !token.isEmpty else { return false }
        return exhaustedTokens().contains(token)
    }

    static func clearExhaustedRewards() {
        UserDefaults.standard.removeObject(forKey: exhaustedKey)
    }

    private static func exhaustionToken(orderId: String, brandName: String) -> String {
        let order = orderId.trimmingCharacters(in: .whitespacesAndNewlines)
        let brand = brandName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !order.isEmpty, !brand.isEmpty else { return "" }
        return "\(brand)|\(order)"
    }

    private static func exhaustedTokens() -> Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: exhaustedKey) ?? [])
    }
}
