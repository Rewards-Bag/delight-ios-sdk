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
}
