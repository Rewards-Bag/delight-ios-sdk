import Foundation

enum DelightRewardSelectionService {
    private static let storagePrefix = "delight.stagecoach.reward-state.v5"
    private static let ticketTypesWithAgeGate: Set<String> = ["child", "young-person"]
    fileprivate static let secondsInDay: TimeInterval = 24 * 60 * 60

    /// Retention: drop local history older than this (garbage-collected on each SDK call).
    fileprivate static let retentionDays: TimeInterval = 90
    /// Monthly impression cap uses a rolling window of this many days.
    private static let monthlyCapWindowDays: TimeInterval = 30
    /// Ignore rotation counts qualified ignores in this rolling window.
    private static let ignoreRotationWindowDays: TimeInterval = 30
    private static let clickSuppressionDays: TimeInterval = 90
    private static let maxImpressionsInRollingMonth = 12

    static func selectConfig(
        from config: DelightConfigDTO,
        payload: DelightRequestPayload,
        ignoreLocalRulesForTesting: Bool,
        ignoreCooldownForLocalDevelopment: Bool
    ) -> DelightConfigDTO? {
        guard let popup = config.popup else { return nil }

        let userKey = userToken(from: payload)
        guard !userKey.isEmpty else { return nil }

        let now = Date()
        var state = loadState(for: userKey)
        state.prune(now: now)
        saveState(state, for: userKey)

        // 1) Monthly cap (rolling 30 days) — hard stop before pool selection.
        if !ignoreLocalRulesForTesting, !passesMonthlyImpressionCap(state: state, now: now) {
            return nil
        }

        // 2) 24h cooldown since last impression — hard stop (optional bypass for local dev only).
        let bypassCooldown = ignoreLocalRulesForTesting || ignoreCooldownForLocalDevelopment
        if !bypassCooldown, !passesCooldown(state: state, now: now) {
            return nil
        }

        let selectedTicketTypes = normalizedTicketTypes(from: payload.ticketTypes)
        let baseRewards = (popup.rewards ?? []).filter { $0.show != false }
        let ageEligibleRewards = applyAgeSuppression(to: baseRewards, selectedTicketTypes: selectedTicketTypes)
        guard !ageEligibleRewards.isEmpty else {
            return nil
        }

        // 3) Click suppression (90d), 4) ignore rotation (3 qualified ignores in 30d).
        let pool = applyPerRewardFilters(to: ageEligibleRewards, state: state, now: now)
        guard let selectedReward = pickStickyReward(
            from: pool,
            selectedTicketTypes: selectedTicketTypes,
            state: state
        ) else {
            return nil
        }

        // Impression is logged when the reward becomes visible (`recordVisibleImpression`).

        let singleRewardPopup = DelightPopupSectionDTO(
            enabled: popup.enabled,
            defaultLocale: popup.defaultLocale,
            locales: popup.locales,
            theme: popup.theme,
            rewards: [selectedReward]
        )

        return DelightConfigDTO(
            partnerId: config.partnerId,
            partnerLogo: config.partnerLogo,
            apiUrl: config.apiUrl,
            language: config.language,
            popup: singleRewardPopup
        )
    }

    /// Backward-compatible overload for call sites that don't pass cooldown bypass explicitly.
    static func selectConfig(
        from config: DelightConfigDTO,
        payload: DelightRequestPayload,
        ignoreLocalRulesForTesting: Bool
    ) -> DelightConfigDTO? {
        selectConfig(
            from: config,
            payload: payload,
            ignoreLocalRulesForTesting: ignoreLocalRulesForTesting,
            ignoreCooldownForLocalDevelopment: false
        )
    }

    /// Call when the popup is actually on-screen (one per presentation).
    static func recordVisibleImpression(
        payload: DelightRequestPayload,
        rewardId: String,
        at date: Date
    ) {
        guard !rewardId.isEmpty else { return }
        let userKey = userToken(from: payload)
        guard !userKey.isEmpty else { return }

        var state = loadState(for: userKey)
        state.prune(now: date)
        state.recordVisibleImpression(rewardId: rewardId, at: date)
        saveState(state, for: userKey)
    }

    static func recordClick(payload: DelightRequestPayload, rewardId: String?) {
        guard let rewardId, !rewardId.isEmpty else { return }

        let userKey = userToken(from: payload)
        guard !userKey.isEmpty else { return }

        var state = loadState(for: userKey)
        state.prune(now: Date())
        state.recordClick(rewardId: rewardId, at: Date())
        saveState(state, for: userKey)
    }

    static func recordIgnore(payload: DelightRequestPayload, rewardId: String, at date: Date) {
        guard !rewardId.isEmpty else { return }
        let userKey = userToken(from: payload)
        guard !userKey.isEmpty else { return }

        var state = loadState(for: userKey)
        state.prune(now: date)
        state.recordQualifiedIgnore(rewardId: rewardId, at: date)
        saveState(state, for: userKey)
    }

    private static func passesMonthlyImpressionCap(state: UserRewardState, now: Date) -> Bool {
        let windowStart = now.addingTimeInterval(-monthlyCapWindowDays * secondsInDay)
        let recent = state.globalImpressions.filter { $0 >= windowStart }
        return recent.count < maxImpressionsInRollingMonth
    }

    private static func passesCooldown(state: UserRewardState, now: Date) -> Bool {
        guard let lastImpressionAt = state.globalImpressions.max() else { return true }
        return now.timeIntervalSince(lastImpressionAt) >= secondsInDay
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

    private static func applyPerRewardFilters(
        to rewards: [DelightPopupRewardDTO],
        state: UserRewardState,
        now: Date
    ) -> [DelightPopupRewardDTO] {
        rewards.filter { reward in
            guard let id = reward.id, !id.isEmpty else { return false }
            let rewardState = state.rewardStates[id] ?? .init()

            if let lastClickAt = rewardState.lastClickAt,
               now.timeIntervalSince(lastClickAt) < clickSuppressionDays * secondsInDay {
                return false
            }

            let ignoreWindowStart = now.addingTimeInterval(-ignoreRotationWindowDays * secondsInDay)
            let recentIgnores = rewardState.qualifiedIgnoreDates.filter { $0 >= ignoreWindowStart }
            if recentIgnores.count >= 3 {
                return false
            }

            return true
        }
    }

    /// Keeps showing the same reward while it stays in the filtered pool; when it drops off (e.g. ignore rotation), advances to the first remaining reward in config order.
    private static func pickStickyReward(
        from filteredRewards: [DelightPopupRewardDTO],
        selectedTicketTypes: [String],
        state: UserRewardState
    ) -> DelightPopupRewardDTO? {
        guard !filteredRewards.isEmpty else { return nil }

        let pool: [DelightPopupRewardDTO]
        if selectedTicketTypes.isEmpty {
            pool = filteredRewards
        } else {
            let selectedTypeSet = Set(selectedTicketTypes)
            let matchingRewards = filteredRewards.filter { reward in
                guard let type = reward.ticketType?.lowercased() else { return false }
                return selectedTypeSet.contains(type)
            }
            pool = matchingRewards.isEmpty ? filteredRewards : matchingRewards
        }

        if let lastId = state.lastShownRewardId,
           let sticky = pool.first(where: { $0.id == lastId }) {
            return sticky
        }
        return pool.first
    }

    private static func userToken(from payload: DelightRequestPayload) -> String {
        let explicitToken = payload.userToken?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        return explicitToken
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

    static func clearLocalData() {
        let defaults = UserDefaults.standard
        defaults.dictionaryRepresentation().keys
            .filter { $0.hasPrefix(storagePrefix) }
            .forEach { defaults.removeObject(forKey: $0) }
    }
}

private struct UserRewardState: Codable {
    var globalImpressions: [Date] = []
    var rewardStates: [String: RewardState] = [:]
    /// Last reward that was actually shown (visible impression); drives sticky selection until ineligible.
    var lastShownRewardId: String?

    enum CodingKeys: String, CodingKey {
        case globalImpressions
        case rewardStates
        case lastShownRewardId
    }

    init(
        globalImpressions: [Date] = [],
        rewardStates: [String: RewardState] = [:],
        lastShownRewardId: String? = nil
    ) {
        self.globalImpressions = globalImpressions
        self.rewardStates = rewardStates
        self.lastShownRewardId = lastShownRewardId
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        globalImpressions = try container.decodeIfPresent([Date].self, forKey: .globalImpressions) ?? []
        rewardStates = try container.decodeIfPresent([String: RewardState].self, forKey: .rewardStates) ?? [:]
        lastShownRewardId = try container.decodeIfPresent(String.self, forKey: .lastShownRewardId)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(globalImpressions, forKey: .globalImpressions)
        try container.encode(rewardStates, forKey: .rewardStates)
        try container.encodeIfPresent(lastShownRewardId, forKey: .lastShownRewardId)
    }

    mutating func prune(now: Date) {
        let cutoff = now.addingTimeInterval(-DelightRewardSelectionService.retentionDays * DelightRewardSelectionService.secondsInDay)
        globalImpressions = globalImpressions.filter { $0 >= cutoff }

        for (rewardId, rewardState) in rewardStates {
            var next = rewardState
            next.impressions = next.impressions.filter { $0 >= cutoff }
            next.qualifiedIgnoreDates = next.qualifiedIgnoreDates.filter { $0 >= cutoff }
            if let lastClickAt = next.lastClickAt, lastClickAt < cutoff {
                next.lastClickAt = nil
            }
            rewardStates[rewardId] = next
        }
    }

    mutating func recordVisibleImpression(rewardId: String, at date: Date) {
        globalImpressions.append(date)
        var rewardState = rewardStates[rewardId] ?? .init()
        rewardState.impressions.append(date)
        rewardStates[rewardId] = rewardState
        lastShownRewardId = rewardId
    }

    mutating func recordClick(rewardId: String, at date: Date) {
        var rewardState = rewardStates[rewardId] ?? .init()
        rewardState.lastClickAt = date
        rewardState.qualifiedIgnoreDates = []
        rewardStates[rewardId] = rewardState
    }

    mutating func recordQualifiedIgnore(rewardId: String, at date: Date) {
        var rewardState = rewardStates[rewardId] ?? .init()
        rewardState.qualifiedIgnoreDates.append(date)
        rewardStates[rewardId] = rewardState
    }
}

private struct RewardState: Codable {
    var impressions: [Date] = []
    var lastClickAt: Date?
    var qualifiedIgnoreDates: [Date] = []

    enum CodingKeys: String, CodingKey {
        case impressions
        case lastClickAt
        case qualifiedIgnoreDates
        case unengagedImpressions
        case ignores
    }

    init(
        impressions: [Date] = [],
        lastClickAt: Date? = nil,
        qualifiedIgnoreDates: [Date] = []
    ) {
        self.impressions = impressions
        self.lastClickAt = lastClickAt
        self.qualifiedIgnoreDates = qualifiedIgnoreDates
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        impressions = try container.decodeIfPresent([Date].self, forKey: .impressions) ?? []
        lastClickAt = try container.decodeIfPresent(Date.self, forKey: .lastClickAt)

        if let q = try container.decodeIfPresent([Date].self, forKey: .qualifiedIgnoreDates), !q.isEmpty {
            qualifiedIgnoreDates = q
        } else {
            let legacyUE = try container.decodeIfPresent([Date].self, forKey: .unengagedImpressions) ?? []
            let legacyIgnores = try container.decodeIfPresent([Date].self, forKey: .ignores) ?? []
            qualifiedIgnoreDates = legacyUE + legacyIgnores
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(impressions, forKey: .impressions)
        try container.encodeIfPresent(lastClickAt, forKey: .lastClickAt)
        try container.encode(qualifiedIgnoreDates, forKey: .qualifiedIgnoreDates)
    }
}
