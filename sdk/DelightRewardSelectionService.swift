import Foundation

enum DelightRewardSelectionService {
    private static let storagePrefix = "delight.stagecoach.reward-state.v3"
    private static let ticketTypesWithAgeGate: Set<String> = ["child", "young-person"]
    fileprivate static let calendar = Calendar(identifier: .gregorian)
    fileprivate static let secondsInDay: TimeInterval = 24 * 60 * 60

    static func selectConfig(
        from config: DelightConfigDTO,
        payload: DelightRequestPayload,
        ignoreLocalRulesForTesting: Bool
    ) -> DelightConfigDTO? {
        guard let popup = config.popup else { return nil }
        let ignoreRules = ignoreLocalRulesForTesting

        let userKey = userToken(from: payload)
        guard !userKey.isEmpty else { return nil }

        let now = Date()
        var state = loadState(for: userKey)
        state.prune(now: now)

        guard ignoreRules || canShowPopup(state: state, now: now) else {
            saveState(state, for: userKey)
            return nil
        }

        let selectedTicketTypes = normalizedTicketTypes(from: payload.ticketTypes)
        let baseRewards = (popup.rewards ?? []).filter { $0.show != false }
        let ageEligibleRewards = applyAgeSuppression(to: baseRewards, selectedTicketTypes: selectedTicketTypes)
        guard !ageEligibleRewards.isEmpty else {
            saveState(state, for: userKey)
            return nil
        }

        let eligibleRewards = ignoreRules
            ? ageEligibleRewards
            : applyPerRewardSuppression(to: ageEligibleRewards, state: state, now: now)

        guard let selectedReward = chooseReward(from: eligibleRewards, selectedTicketTypes: selectedTicketTypes) else {
            saveState(state, for: userKey)
            return nil
        }

        if !ignoreRules {
            state.recordImpression(rewardId: selectedReward.id, at: now)
            saveState(state, for: userKey)
        }

        let singleRewardPopup = DelightPopupSectionDTO(
            enabled: popup.enabled,
            defaultLocale: popup.defaultLocale,
            locales: popup.locales,
            theme: popup.theme,
            rewards: [selectedReward]
        )

        return DelightConfigDTO(
            partnerLogo: config.partnerLogo,
            language: config.language,
            popup: singleRewardPopup
        )
    }

    static func recordClick(
        payload: DelightRequestPayload,
        rewardId: String?,
        ignoreLocalRulesForTesting: Bool
    ) {
        if ignoreLocalRulesForTesting { return }
        guard
            let rewardId,
            !rewardId.isEmpty
        else {
            return
        }

        let userKey = userToken(from: payload)
        guard !userKey.isEmpty else { return }

        var state = loadState(for: userKey)
        state.recordClick(rewardId: rewardId, at: Date())
        saveState(state, for: userKey)
    }

    static func recordIgnore(
        payload: DelightRequestPayload,
        rewardId: String,
        at date: Date,
        ignoreLocalRulesForTesting: Bool
    ) {
        if ignoreLocalRulesForTesting { return }
        let userKey = userToken(from: payload)
        guard !userKey.isEmpty else { return }

        var state = loadState(for: userKey)
        state.prune(now: date)
        state.recordIgnore(rewardId: rewardId, at: date)
        saveState(state, for: userKey)
    }

    private static func canShowPopup(state: UserRewardState, now: Date) -> Bool {
        let inRolling30Days = state.globalImpressions.filter {
            $0 >= now.addingTimeInterval(-30 * secondsInDay)
        }
        guard inRolling30Days.count < 12 else { return false }

        if let lastImpressionAt = state.globalImpressions.max(),
           now.timeIntervalSince(lastImpressionAt) < secondsInDay {
            return false
        }

        return true
    }

    private static func normalizedTicketTypes(from rawTypes: [String]) -> [String] {
        var seen = Set<String>()
        var normalized: [String] = []
        for type in rawTypes {
            let value = type.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !value.isEmpty, !seen.contains(value) else { continue }
            seen.insert(value)
            normalized.append(value)
        }
        return normalized
    }

    private static func applyAgeSuppression(
        to rewards: [DelightPopupRewardDTO],
        selectedTicketTypes: [String]
    ) -> [DelightPopupRewardDTO] {
        let shouldSuppress18Plus = !Set(selectedTicketTypes).isDisjoint(with: ticketTypesWithAgeGate)
        guard shouldSuppress18Plus else { return rewards }

        return rewards.filter { reward in
            reward.ageRequirement?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() != "18+"
        }
    }

    private static func applyPerRewardSuppression(
        to rewards: [DelightPopupRewardDTO],
        state: UserRewardState,
        now: Date
    ) -> [DelightPopupRewardDTO] {
        rewards.filter { reward in
            guard let id = reward.id, !id.isEmpty else { return false }
            let rewardState = state.rewardStates[id] ?? .init()

            // 1) Max 3 impressions of this reward without engagement in rolling 30 days.
            if rewardState.unengagedImpressions.count >= 3 {
                return false
            }

            // 2) Ignore-suppressed in last 30 days.
            if let ignoreSuppressedUntil = rewardState.ignoreSuppressedUntil, ignoreSuppressedUntil > now {
                return false
            }

            // 3) Clicked reward suppression for 90 days.
            if let lastClickAt = rewardState.lastClickAt,
               now.timeIntervalSince(lastClickAt) < 90 * secondsInDay {
                return false
            }

            return true
        }
    }

    private static func userToken(from payload: DelightRequestPayload) -> String {
        // Local SDK-only token (UserDefaults key suffix). No server persistence.
        let explicitToken = payload.userToken?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        if !explicitToken.isEmpty { return explicitToken }
        let email = payload.email?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        if !email.isEmpty { return email }
        return payload.orderId?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
    }

    private static func chooseReward(
        from rewards: [DelightPopupRewardDTO],
        selectedTicketTypes: [String]
    ) -> DelightPopupRewardDTO? {
        guard !rewards.isEmpty else { return nil }
        guard !selectedTicketTypes.isEmpty else { return rewards.first }

        var leadCandidates: [DelightPopupRewardDTO] = []
        var seenIds = Set<String>()

        for ticketType in selectedTicketTypes {
            if let lead = rewards.first(where: { $0.ticketType?.lowercased() == ticketType }),
               let id = lead.id,
               !seenIds.contains(id) {
                seenIds.insert(id)
                leadCandidates.append(lead)
            }
        }

        if leadCandidates.count == 1 {
            return leadCandidates[0]
        }

        if leadCandidates.count > 1 {
            return leadCandidates.randomElement()
        }

        return rewards.first
    }

    private static func userDefaultsKey(for userKey: String) -> String {
        "\(storagePrefix).\(userKey)"
    }

    private static func loadState(for userKey: String) -> UserRewardState {
        let key = userDefaultsKey(for: userKey)
        guard
            let data = UserDefaults.standard.data(forKey: key),
            let state = try? JSONDecoder().decode(UserRewardState.self, from: data)
        else {
            return .init()
        }
        return state
    }

    private static func saveState(_ state: UserRewardState, for userKey: String) {
        let key = userDefaultsKey(for: userKey)
        guard let data = try? JSONEncoder().encode(state) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}

private struct UserRewardState: Codable {
    var globalImpressions: [Date] = []
    var rewardStates: [String: RewardState] = [:]

    mutating func prune(now: Date) {
        let rolling30 = now.addingTimeInterval(-30 * DelightRewardSelectionService.secondsInDay)
        globalImpressions = globalImpressions.filter { $0 >= rolling30 }

        for (rewardId, rewardState) in rewardStates {
            var next = rewardState
            next.impressions = next.impressions.filter { $0 >= rolling30 }
            next.unengagedImpressions = next.unengagedImpressions.filter { $0 >= rolling30 }
            next.ignores = next.ignores.filter { $0 >= rolling30 }
            if let ignoreSuppressedUntil = next.ignoreSuppressedUntil, ignoreSuppressedUntil <= now {
                next.ignoreSuppressedUntil = nil
            }
            rewardStates[rewardId] = next
        }
    }

    mutating func recordImpression(rewardId: String?, at date: Date) {
        globalImpressions.append(date)
        guard let rewardId, !rewardId.isEmpty else { return }

        var rewardState = rewardStates[rewardId] ?? .init()
        rewardState.impressions.append(date)
        rewardState.unengagedImpressions.append(date)
        rewardStates[rewardId] = rewardState
    }

    mutating func recordClick(rewardId: String, at date: Date) {
        var rewardState = rewardStates[rewardId] ?? .init()
        rewardState.lastClickAt = date
        rewardState.unengagedImpressions = []
        rewardStates[rewardId] = rewardState
    }

    mutating func recordIgnore(rewardId: String, at date: Date) {
        var rewardState = rewardStates[rewardId] ?? .init()
        rewardState.ignores.append(date)
        if rewardState.ignores.count >= 3 {
            rewardState.ignoreSuppressedUntil = date.addingTimeInterval(30 * DelightRewardSelectionService.secondsInDay)
            rewardState.ignores = []
        }
        rewardStates[rewardId] = rewardState
    }
}

private struct RewardState: Codable {
    var impressions: [Date] = []
    var lastClickAt: Date?
    var unengagedImpressions: [Date] = []
    var ignores: [Date] = []
    var ignoreSuppressedUntil: Date?

    init(
        impressions: [Date] = [],
        lastClickAt: Date? = nil,
        unengagedImpressions: [Date] = [],
        ignores: [Date] = [],
        ignoreSuppressedUntil: Date? = nil
    ) {
        self.impressions = impressions
        self.lastClickAt = lastClickAt
        self.unengagedImpressions = unengagedImpressions
        self.ignores = ignores
        self.ignoreSuppressedUntil = ignoreSuppressedUntil
    }

    enum CodingKeys: String, CodingKey {
        case impressions
        case lastClickAt
        case unengagedImpressions
        case ignores
        case ignoreSuppressedUntil
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        impressions = try container.decodeIfPresent([Date].self, forKey: .impressions) ?? []
        lastClickAt = try container.decodeIfPresent(Date.self, forKey: .lastClickAt)
        unengagedImpressions = try container.decodeIfPresent([Date].self, forKey: .unengagedImpressions) ?? []
        ignores = try container.decodeIfPresent([Date].self, forKey: .ignores) ?? []
        ignoreSuppressedUntil = try container.decodeIfPresent(Date.self, forKey: .ignoreSuppressedUntil)
    }
}
