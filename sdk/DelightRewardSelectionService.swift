import Foundation

enum DelightRewardSelectionService {
    private static let storagePrefix = "delight.stagecoach.reward-state.v7"
    private static let ticketTypesWithAgeGate: Set<String> = ["child", "young-person"]
    fileprivate static let secondsInDay: TimeInterval = 24 * 60 * 60
    fileprivate static let secondsInHour: TimeInterval = 60 * 60

    /// When `true`, `dailyCooldownHours` from config is treated as 0 (QA / local testing).
    static var ignoreDailyCooldownHours = false

    fileprivate static var gmtTimeZone: TimeZone {
        TimeZone(identifier: "GMT") ?? TimeZone(secondsFromGMT: 0)!
    }

    private static var gmtCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = gmtTimeZone
        return calendar
    }

    static func selectConfig(
        from config: DelightConfigDTO,
        payload: DelightRequestPayload,
        now: Date = Date()
    ) -> DelightConfigDTO? {
        guard let popup = config.popup else { return nil }

        let userKey = userToken(from: payload)
        guard !userKey.isEmpty else { return nil }

        let rules = DelightSuppressionRules.resolved(from: config.suppressionRules)
        var state = loadState(for: userKey)
        state.prune(now: now, retentionDays: rules.retentionDays)
        syncFatigueRestIfNeeded(state: &state, rules: rules, now: now)

        if let orderId = normalizedOrderId(from: payload),
           let assignedRewardId = state.transactionRewards[orderId],
           let assignedReward = reward(withId: assignedRewardId, in: popup.rewards ?? []) {
            saveState(state, for: userKey)
            return rewardsConfig(from: config, rewards: [assignedReward])
        }

        if !passesMonthlyImpressionCap(state: state, now: now, rules: rules) {
            saveState(state, for: userKey)
            return nil
        }

        let todayRewardIds = impressedRewardIds(for: state, on: now)
        if todayRewardIds.count >= rules.maxRewardsPerUserPerDay {
            saveState(state, for: userKey)
            return nil
        }

        if todayRewardIds.count == 1,
           !passesDailyCooldown(state: state, now: now, rules: rules) {
            saveState(state, for: userKey)
            return nil
        }

        let selectedTicketTypes = normalizedTicketTypes(from: payload.ticketTypes)
        guard !selectedTicketTypes.isEmpty else {
            saveState(state, for: userKey)
            return nil
        }

        let baseRewards = (popup.rewards ?? []).filter { $0.show != false }
        guard let selectedReward = pickEligibleReward(
            selectedTicketTypes: selectedTicketTypes,
            baseRewards: baseRewards,
            state: state,
            now: now,
            rules: rules,
            excludingRewardIds: Set(todayRewardIds)
        ) else {
            saveState(state, for: userKey)
            return nil
        }

        if let orderId = normalizedOrderId(from: payload),
           let rewardId = selectedReward.id {
            state.transactionRewards[orderId] = rewardId
        }
        saveState(state, for: userKey)

        return rewardsConfig(from: config, rewards: [selectedReward])
    }

    /// First render only. Reopening from the minimized icon must not call this again for the same transaction.
    static func recordVisibleImpression(
        payload: DelightRequestPayload,
        rewardId: String,
        at date: Date,
        suppressionRules: DelightSuppressionRulesDTO? = nil
    ) {
        guard !rewardId.isEmpty else { return }
        let userKey = userToken(from: payload)
        guard !userKey.isEmpty else { return }

        let rules = DelightSuppressionRules.resolved(from: suppressionRules)
        var state = loadState(for: userKey)
        state.prune(now: date, retentionDays: rules.retentionDays)
        syncFatigueRestIfNeeded(state: &state, rules: rules, now: date)

        if let orderId = normalizedOrderId(from: payload),
           state.transactionImpressionDates[orderId] != nil {
            saveState(state, for: userKey)
            return
        }

        state.recordVisibleImpression(rewardId: rewardId, at: date, rules: rules)

        if let orderId = normalizedOrderId(from: payload) {
            state.transactionImpressionDates[orderId] = date
        }

        saveState(state, for: userKey)
    }

    static func recordClick(payload: DelightRequestPayload, rewardId: String?) {
        guard let rewardId, !rewardId.isEmpty else { return }

        let userKey = userToken(from: payload)
        guard !userKey.isEmpty else { return }

        var state = loadState(for: userKey)
        let rules = DelightSuppressionRules.resolved(from: nil)
        state.prune(now: Date(), retentionDays: rules.retentionDays)
        state.recordClick(rewardId: rewardId, at: Date())
        saveState(state, for: userKey)
    }

    static func recordIgnore(payload: DelightRequestPayload, rewardId: String, at date: Date) {
        _ = payload
        _ = rewardId
        _ = date
    }

    static func clearLocalData() {
        let defaults = UserDefaults.standard
        defaults.dictionaryRepresentation().keys
            .filter { $0.hasPrefix(storagePrefix) || $0.hasPrefix("delight.stagecoach.reward-state.") }
            .forEach { defaults.removeObject(forKey: $0) }
    }

    /// Clears today's daily reward slots for all stored users, mimicking a GMT midnight rollover.
    /// Fatigue, click suppression, and monthly impression history are preserved.
    static func resetDailySuppressionState(now: Date = Date()) {
        let defaults = UserDefaults.standard
        for key in defaults.dictionaryRepresentation().keys {
            guard key.hasPrefix(storagePrefix) || key.hasPrefix("delight.stagecoach.reward-state.") else {
                continue
            }
            guard
                let data = defaults.data(forKey: key),
                var state = try? JSONDecoder().decode(UserRewardState.self, from: data)
            else {
                continue
            }
            state.resetDailyState(for: now)
            guard let encoded = try? JSONEncoder().encode(state) else { continue }
            defaults.set(encoded, forKey: key)
        }
    }

    private static func rewardsConfig(
        from config: DelightConfigDTO,
        rewards: [DelightPopupRewardDTO]
    ) -> DelightConfigDTO {
        let rewardsPopup = DelightPopupSectionDTO(
            enabled: config.popup?.enabled,
            defaultLocale: config.popup?.defaultLocale,
            locales: config.popup?.locales,
            theme: config.popup?.theme,
            rewards: rewards
        )

        return DelightConfigDTO(
            partnerId: config.partnerId,
            partnerLogo: config.partnerLogo,
            apiUrl: config.apiUrl,
            language: config.language,
            popup: rewardsPopup,
            suppressionRules: config.suppressionRules
        )
    }

    private static func orderedRewardsForTicketTypes(
        selectedTicketTypes: [String],
        baseRewards: [DelightPopupRewardDTO]
    ) -> [DelightPopupRewardDTO] {
        var ordered: [DelightPopupRewardDTO] = []
        var seenRewardIds = Set<String>()

        for ticketType in selectedTicketTypes {
            for reward in rewardsForTicketType(ticketType, from: baseRewards) {
                guard let rewardId = reward.id, !seenRewardIds.contains(rewardId) else { continue }
                ordered.append(reward)
                seenRewardIds.insert(rewardId)
            }
        }

        return ordered
    }

    private static func pickEligibleReward(
        selectedTicketTypes: [String],
        baseRewards: [DelightPopupRewardDTO],
        state: UserRewardState,
        now: Date,
        rules: DelightSuppressionRules,
        excludingRewardIds: Set<String>
    ) -> DelightPopupRewardDTO? {
        let typeOrder = orderedRewardsForTicketTypes(
            selectedTicketTypes: selectedTicketTypes,
            baseRewards: baseRewards
        )
        let ageEligibleRewards = applyAgeSuppression(to: typeOrder, selectedTicketTypes: selectedTicketTypes)
        let pool = applyPerRewardFilters(
            to: ageEligibleRewards,
            state: state,
            now: now,
            rules: rules,
            excludingRewardIds: excludingRewardIds
        )
        return pickFirstEligibleInOrder(
            typeOrder: ageEligibleRewards,
            poolIds: Set(pool.compactMap(\.id))
        )
    }

    private static func reward(withId id: String, in rewards: [DelightPopupRewardDTO]) -> DelightPopupRewardDTO? {
        rewards.first { $0.id == id && $0.show != false }
    }

    private static func passesDailyCooldown(
        state: UserRewardState,
        now: Date,
        rules: DelightSuppressionRules
    ) -> Bool {
        guard rules.dailyCooldownHours > 0 else { return true }

        let dayKey = gmtDayKey(for: now)
        guard let firstImpressionAt = state.firstDailyImpressionAt[dayKey] else { return true }

        let cooldownSeconds = rules.dailyCooldownHours * secondsInHour
        return now.timeIntervalSince(firstImpressionAt) >= cooldownSeconds
    }

    private static func pickFirstEligibleInOrder(
        typeOrder: [DelightPopupRewardDTO],
        poolIds: Set<String>
    ) -> DelightPopupRewardDTO? {
        typeOrder.first { reward in
            guard let id = reward.id else { return false }
            return poolIds.contains(id)
        }
    }

    private static func passesMonthlyImpressionCap(
        state: UserRewardState,
        now: Date,
        rules: DelightSuppressionRules
    ) -> Bool {
        let monthKey = gmtMonthKey(for: now)
        let monthImpressions = state.globalImpressions.filter { gmtMonthKey(for: $0) == monthKey }
        return monthImpressions.count < rules.maxImpressionsPerUserPerMonth
    }

    private static func impressedRewardIds(for state: UserRewardState, on date: Date) -> [String] {
        state.dailyImpressedRewardIds[gmtDayKey(for: date)] ?? []
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
        now: Date,
        rules: DelightSuppressionRules,
        excludingRewardIds: Set<String>
    ) -> [DelightPopupRewardDTO] {
        rewards.filter { reward in
            guard let id = reward.id, !id.isEmpty else { return false }
            if excludingRewardIds.contains(id) { return false }

            let rewardState = rewardStateForSelection(state.rewardStates[id] ?? .init(), rules: rules, now: now)
            return !isClickSuppressed(rewardState: rewardState, now: now, rules: rules)
                && !isFatigueSuppressed(rewardState: rewardState, now: now, rules: rules)
        }
    }

    private static func isClickSuppressed(
        rewardState: RewardState,
        now: Date,
        rules: DelightSuppressionRules
    ) -> Bool {
        guard let lastClickAt = rewardState.lastClickAt else { return false }
        return now.timeIntervalSince(lastClickAt) < rules.suppressionPeriodAfterClickDays * secondsInDay
    }

    private static func isFatigueSuppressed(
        rewardState: RewardState,
        now: Date,
        rules: DelightSuppressionRules
    ) -> Bool {
        _ = rules
        guard let restUntil = rewardState.fatigueRestUntil else { return false }
        return now < restUntil
    }

    private static func rewardStateForSelection(
        _ rewardState: RewardState,
        rules: DelightSuppressionRules,
        now: Date
    ) -> RewardState {
        var updated = rewardState

        if let restUntil = updated.fatigueRestUntil, now >= restUntil {
            updated.fatigueRestUntil = nil
            if let lastClickAt = updated.lastClickAt {
                updated.impressions = updated.impressions.filter { $0 <= lastClickAt }
            } else {
                updated.impressions = []
            }
        }

        guard updated.fatigueRestUntil == nil,
              updated.unengagedImpressionCount() >= rules.maxImpressionsPerRewardWithoutEngagement,
              rules.restPeriodAfterNoEngagementDays > 0,
              let lastImpression = updated.impressions.max() else {
            return updated
        }

        updated.fatigueRestUntil = lastImpression.addingTimeInterval(
            rules.restPeriodAfterNoEngagementDays * secondsInDay
        )
        return updated
    }

    private static func syncFatigueRestIfNeeded(
        state: inout UserRewardState,
        rules: DelightSuppressionRules,
        now: Date
    ) {
        guard rules.restPeriodAfterNoEngagementDays > 0 else { return }

        for rewardId in state.rewardStates.keys {
            state.rewardStates[rewardId] = rewardStateForSelection(
                state.rewardStates[rewardId] ?? .init(),
                rules: rules,
                now: now
            )
        }
    }

    private static func rewardsForTicketType(
        _ ticketType: String,
        from rewards: [DelightPopupRewardDTO]
    ) -> [DelightPopupRewardDTO] {
        let normalizedType = normalizedTicketType(ticketType)
        guard !normalizedType.isEmpty else { return [] }

        return rewards.filter { reward in
            guard let id = reward.id, !id.isEmpty, reward.show != false else { return false }
            return normalizedTicketType(reward.ticketType) == normalizedType
        }
    }

    private static func normalizedTicketType(_ rawType: String?) -> String {
        rawType?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? ""
    }

    private static func normalizedOrderId(from payload: DelightRequestPayload) -> String? {
        let value = payload.orderId?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return value.isEmpty ? nil : value
    }

    private static func userToken(from payload: DelightRequestPayload) -> String {
        payload.userToken?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? ""
    }

    private static func gmtDayKey(for date: Date) -> String {
        let components = gmtCalendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
    }

    private static func gmtMonthKey(for date: Date) -> String {
        let components = gmtCalendar.dateComponents([.year, .month], from: date)
        return String(format: "%04d-%02d", components.year ?? 0, components.month ?? 0)
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

private struct DelightSuppressionRules {
    let maxImpressionsPerUserPerMonth: Int
    let maxRewardsPerUserPerDay: Int
    let dailyCooldownHours: TimeInterval
    let maxImpressionsPerRewardWithoutEngagement: Int
    let restPeriodAfterNoEngagementDays: TimeInterval
    let suppressionPeriodAfterClickDays: TimeInterval
    let retentionDays: TimeInterval

    /// Values come from `config.suppressionRules`. Defaults below apply only when a field is missing from the CDN/bundled config.
    static func resolved(from dto: DelightSuppressionRulesDTO?) -> DelightSuppressionRules {
        let dailyCooldownHours: TimeInterval
        if DelightRewardSelectionService.ignoreDailyCooldownHours {
            dailyCooldownHours = 0
        } else {
            dailyCooldownHours = TimeInterval(dto?.dailyCooldownHours ?? 5)
        }

        return DelightSuppressionRules(
            maxImpressionsPerUserPerMonth: dto?.maxImpressionsPerUserPerMonth ?? 15,
            maxRewardsPerUserPerDay: dto?.maxRewardsPerUserPerDay ?? 2,
            dailyCooldownHours: dailyCooldownHours,
            maxImpressionsPerRewardWithoutEngagement: dto?.maxImpressionsPerRewardWithoutEngagement ?? 3,
            restPeriodAfterNoEngagementDays: TimeInterval(dto?.restPeriodAfterNoEngagementDays ?? 21),
            suppressionPeriodAfterClickDays: TimeInterval(dto?.suppressionPeriodAfterClickDays ?? 45),
            retentionDays: TimeInterval(dto?.retentionDays ?? 90)
        )
    }
}

private struct UserRewardState: Codable {
    /// Per-reward history keyed by config reward id. Survives weekly config rotations.
    var globalImpressions: [Date] = []
    var rewardStates: [String: RewardState] = [:]
    var dailyImpressedRewardIds: [String: [String]] = [:]
    var firstDailyImpressionAt: [String: Date] = [:]
    var transactionRewards: [String: String] = [:]
    var transactionRewardIds: [String: [String]] = [:]
    var transactionImpressionDates: [String: Date] = [:]

    enum CodingKeys: String, CodingKey {
        case globalImpressions
        case rewardStates
        case dailyImpressedRewardIds
        case firstDailyImpressionAt
        case transactionRewards
        case transactionRewardIds
        case transactionImpressionDates
        case lastRotationRewardId
    }

    init(
        globalImpressions: [Date] = [],
        rewardStates: [String: RewardState] = [:],
        dailyImpressedRewardIds: [String: [String]] = [:],
        firstDailyImpressionAt: [String: Date] = [:],
        transactionRewards: [String: String] = [:],
        transactionRewardIds: [String: [String]] = [:],
        transactionImpressionDates: [String: Date] = [:]
    ) {
        self.globalImpressions = globalImpressions
        self.rewardStates = rewardStates
        self.dailyImpressedRewardIds = dailyImpressedRewardIds
        self.firstDailyImpressionAt = firstDailyImpressionAt
        self.transactionRewards = transactionRewards
        self.transactionRewardIds = transactionRewardIds
        self.transactionImpressionDates = transactionImpressionDates
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        globalImpressions = try container.decodeIfPresent([Date].self, forKey: .globalImpressions) ?? []
        rewardStates = try container.decodeIfPresent([String: RewardState].self, forKey: .rewardStates) ?? [:]
        dailyImpressedRewardIds = try container.decodeIfPresent([String: [String]].self, forKey: .dailyImpressedRewardIds) ?? [:]
        firstDailyImpressionAt = try container.decodeIfPresent([String: Date].self, forKey: .firstDailyImpressionAt) ?? [:]
        transactionRewards = try container.decodeIfPresent([String: String].self, forKey: .transactionRewards) ?? [:]
        transactionRewardIds = try container.decodeIfPresent([String: [String]].self, forKey: .transactionRewardIds) ?? [:]
        transactionImpressionDates = try container.decodeIfPresent([String: Date].self, forKey: .transactionImpressionDates) ?? [:]
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(globalImpressions, forKey: .globalImpressions)
        try container.encode(rewardStates, forKey: .rewardStates)
        try container.encode(dailyImpressedRewardIds, forKey: .dailyImpressedRewardIds)
        try container.encode(firstDailyImpressionAt, forKey: .firstDailyImpressionAt)
        try container.encode(transactionRewards, forKey: .transactionRewards)
        try container.encode(transactionRewardIds, forKey: .transactionRewardIds)
        try container.encode(transactionImpressionDates, forKey: .transactionImpressionDates)
    }

    mutating func prune(now: Date, retentionDays: TimeInterval) {
        let cutoff = now.addingTimeInterval(-retentionDays * DelightRewardSelectionService.secondsInDay)
        globalImpressions = globalImpressions.filter { $0 >= cutoff }

        dailyImpressedRewardIds = dailyImpressedRewardIds.filter { dayKey, _ in
            guard let dayDate = Self.dayKeyDate(dayKey) else { return false }
            return dayDate >= cutoff
        }

        firstDailyImpressionAt = firstDailyImpressionAt.filter { dayKey, _ in
            guard let dayDate = Self.dayKeyDate(dayKey) else { return false }
            return dayDate >= cutoff
        }

        transactionImpressionDates = transactionImpressionDates.filter { _, recordedAt in
            recordedAt >= cutoff
        }

        transactionRewards = transactionRewards.filter { orderId, _ in
            guard let impressedAt = transactionImpressionDates[orderId] else { return true }
            return impressedAt >= cutoff
        }

        transactionRewardIds = transactionRewardIds.filter { orderId, _ in
            guard let impressedAt = transactionImpressionDates[orderId] else { return true }
            return impressedAt >= cutoff
        }

        var retainedRewardStates: [String: RewardState] = [:]
        for (rewardId, rewardState) in rewardStates {
            var next = rewardState
            next.impressions = next.impressions.filter { $0 >= cutoff }

            let lastActivity = [
                rewardState.impressions.max(),
                rewardState.lastClickAt
            ].compactMap { $0 }.max()

            guard let lastActivity, lastActivity >= cutoff else {
                continue
            }

            retainedRewardStates[rewardId] = next
        }
        rewardStates = retainedRewardStates
    }

    mutating func recordVisibleImpression(
        rewardId: String,
        at date: Date,
        rules: DelightSuppressionRules
    ) {
        globalImpressions.append(date)

        var rewardState = rewardStates[rewardId] ?? .init()
        rewardState.impressions.append(date)
        if rewardState.unengagedImpressionCount() >= rules.maxImpressionsPerRewardWithoutEngagement,
           rules.restPeriodAfterNoEngagementDays > 0 {
            rewardState.fatigueRestUntil = date.addingTimeInterval(
                rules.restPeriodAfterNoEngagementDays * DelightRewardSelectionService.secondsInDay
            )
        }
        rewardStates[rewardId] = rewardState

        let dayKey = Self.dayKey(for: date)
        var todayRewards = dailyImpressedRewardIds[dayKey] ?? []
        if todayRewards.isEmpty {
            firstDailyImpressionAt[dayKey] = date
        }
        if !todayRewards.contains(rewardId) {
            todayRewards.append(rewardId)
            dailyImpressedRewardIds[dayKey] = todayRewards
        }

        _ = rules
    }

    mutating func recordClick(rewardId: String, at date: Date) {
        var rewardState = rewardStates[rewardId] ?? .init()
        rewardState.lastClickAt = date
        rewardStates[rewardId] = rewardState
    }

    mutating func resetDailyState(for date: Date) {
        let dayKey = Self.dayKey(for: date)
        dailyImpressedRewardIds.removeValue(forKey: dayKey)
        firstDailyImpressionAt.removeValue(forKey: dayKey)
    }

    private static func dayKeyDate(_ dayKey: String) -> Date? {
        let parts = dayKey.split(separator: "-")
        guard parts.count == 3,
              let year = Int(parts[0]),
              let month = Int(parts[1]),
              let day = Int(parts[2]) else {
            return nil
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = DelightRewardSelectionService.gmtTimeZone
        return calendar.date(from: DateComponents(year: year, month: month, day: day))
    }

    private static func dayKey(for date: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = DelightRewardSelectionService.gmtTimeZone
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
    }
}

private struct RewardState: Codable {
    var impressions: [Date] = []
    /// Set when the user claims/clicks through. Drives the click-suppression window.
    var lastClickAt: Date?
    var fatigueRestUntil: Date?

    enum CodingKeys: String, CodingKey {
        case impressions
        case lastClickAt
        case fatigueRestUntil
        case qualifiedIgnoreDates
        case unengagedImpressions
        case ignores
    }

    init(
        impressions: [Date] = [],
        lastClickAt: Date? = nil,
        fatigueRestUntil: Date? = nil
    ) {
        self.impressions = impressions
        self.lastClickAt = lastClickAt
        self.fatigueRestUntil = fatigueRestUntil
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        impressions = try container.decodeIfPresent([Date].self, forKey: .impressions) ?? []
        lastClickAt = try container.decodeIfPresent(Date.self, forKey: .lastClickAt)
        fatigueRestUntil = try container.decodeIfPresent(Date.self, forKey: .fatigueRestUntil)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(impressions, forKey: .impressions)
        try container.encodeIfPresent(lastClickAt, forKey: .lastClickAt)
        try container.encodeIfPresent(fatigueRestUntil, forKey: .fatigueRestUntil)
    }

    func unengagedImpressionCount() -> Int {
        guard let lastClickAt else { return impressions.count }
        return impressions.filter { $0 > lastClickAt }.count
    }
}
