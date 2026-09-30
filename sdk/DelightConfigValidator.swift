import Foundation

/// Validates partner config before any popup UI is built. Invalid config → show nothing (never a broken screen).
enum DelightConfigValidator {
    enum ValidationFailure: Equatable, Error, CustomStringConvertible {
        case popupMissingOrDisabled
        case unsupportedTemplate(String)
        case noVisibleRewards
        case rewardInvalid(rewardId: String?, reason: String)

        var description: String {
            switch self {
            case .popupMissingOrDisabled:
                return "popup missing or disabled"
            case .unsupportedTemplate(let id):
                return "unsupported template \(id)"
            case .noVisibleRewards:
                return "no visible rewards"
            case .rewardInvalid(let rewardId, let reason):
                if let rewardId {
                    return "reward \(rewardId): \(reason)"
                }
                return reason
            }
        }

        var errorDescription: String? { description }
    }

    static func validateForPresentation(_ config: DelightConfigDTO) -> Result<Void, ValidationFailure> {
        guard config.popup?.enabled == true else {
            return .failure(.popupMissingOrDisabled)
        }

        let templateId = config.templateId
        guard DelightTemplateRegistry.supports(templateId: templateId) else {
            return .failure(.unsupportedTemplate(templateId))
        }

        let rewards = config.resolvedRewards
        guard !rewards.isEmpty else {
            return .failure(.noVisibleRewards)
        }

        for reward in rewards {
            if let reason = validateRewardFields(reward, in: config) {
                return .failure(.rewardInvalid(rewardId: reward.id, reason: reason))
            }
        }

        if let rules = config.suppressionRules, !validateSuppressionRules(rules) {
            return .failure(.rewardInvalid(rewardId: nil, reason: "invalid suppressionRules"))
        }

        return .success(())
    }

    private static func validateRewardFields(
        _ reward: DelightPopupRewardDTO,
        in config: DelightConfigDTO
    ) -> String? {
        guard let id = trimmed(reward.id), !id.isEmpty else {
            return "missing reward id"
        }

        let locale = config.resolvedRewardLocale(for: reward)
        let headline = trimmed(locale?.headline)
        let hasHeadline = headline.map { !$0.isEmpty } ?? false
        let hasImage = validHTTPURLString(reward.postPopupMobileImage)
            || validHTTPURLString(reward.postPopupWebImage)

        guard hasHeadline || hasImage else {
            return "reward \(id) missing headline and image"
        }

        if let cta = trimmed(reward.ctaUrl), !cta.isEmpty, !validHTTPURLString(cta) {
            return "reward \(id) has invalid ctaUrl"
        }

        if let logo = trimmed(reward.logo), !logo.isEmpty, !validHTTPURLString(logo) {
            return "reward \(id) has invalid logo URL"
        }

        return nil
    }

    private static func validateSuppressionRules(_ rules: DelightSuppressionRulesDTO) -> Bool {
        let ints = [
            rules.maxImpressionsPerUserPerMonth,
            rules.maxRewardsPerUserPerDay,
            rules.dailyCooldownHours,
            rules.maxImpressionsPerRewardWithoutEngagement,
            rules.restPeriodAfterNoEngagementDays,
            rules.suppressionPeriodAfterClickDays,
            rules.retentionDays
        ]
        for value in ints {
            if let value, value < 0 { return false }
        }
        return true
    }

    private static func trimmed(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func validHTTPURLString(_ value: String?) -> Bool {
        guard let raw = trimmed(value) else { return false }
        guard let url = URL(string: raw), let scheme = url.scheme?.lowercased() else { return false }
        return scheme == "http" || scheme == "https"
    }
}
