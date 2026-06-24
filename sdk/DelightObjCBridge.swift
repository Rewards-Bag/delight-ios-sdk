import Foundation

@objcMembers
public final class DelightObjC: NSObject {
    /// Objective-C bridge for async SDK initialization.
    /// Completion returns `nil` on success or an NSError on failure.
    @objc(initialize:locale:ignoreDailyCooldownHours:completion:)
    public static func initialize(
        _ brandName: String,
        locale: String,
        ignoreDailyCooldownHours: Bool,
        completion: ((NSError?) -> Void)?
    ) {
        Task { @MainActor in
            do {
                try await Delight.initialize(
                    brandName: brandName,
                    locale: locale,
                    ignoreDailyCooldownHours: ignoreDailyCooldownHours
                )
                completion?(nil)
            } catch {
                completion?(error as NSError)
            }
        }
    }

    @objc(initialize:locale:completion:)
    public static func initialize(
        _ brandName: String,
        locale: String,
        completion: ((NSError?) -> Void)?
    ) {
        initialize(brandName, locale: locale, ignoreDailyCooldownHours: false, completion: completion)
    }

    @available(*, deprecated, message: "Use initialize:locale:completion:")
    @objc(initialize:locale:ignoreDailyRewardCap:ignoreMonthlyImpressionCap:repeatFirstEligibleRewardForTesting:completion:)
    public static func initialize(
        _ brandName: String,
        locale: String,
        ignoreDailyRewardCap: Bool,
        ignoreMonthlyImpressionCap: Bool,
        repeatFirstEligibleRewardForTesting: Bool,
        completion: ((NSError?) -> Void)?
    ) {
        initialize(brandName, locale: locale, completion: completion)
    }

    @available(*, deprecated, message: "Use initialize:locale:completion:")
    @objc(initialize:locale:ignoreLocalRulesForTesting:ignoreCooldownForLocalDevelopment:completion:)
    public static func initialize(
        _ brandName: String,
        locale: String,
        ignoreLocalRulesForTesting: Bool,
        ignoreCooldownForLocalDevelopment: Bool,
        completion: ((NSError?) -> Void)?
    ) {
        initialize(
            brandName,
            locale: locale,
            ignoreDailyCooldownHours: ignoreCooldownForLocalDevelopment,
            completion: completion
        )
    }

    @available(*, deprecated, message: "Use initialize:locale:ignoreDailyCooldownHours:completion:")
    @objc(initialize:ignoreLocalRulesForTesting:ignoreCooldownForLocalDevelopment:completion:)
    public static func initialize(
        _ brandName: String,
        ignoreLocalRulesForTesting: Bool,
        ignoreCooldownForLocalDevelopment: Bool,
        completion: ((NSError?) -> Void)?
    ) {
        initialize(
            brandName,
            locale: "en",
            ignoreDailyCooldownHours: ignoreCooldownForLocalDevelopment,
            completion: completion
        )
    }

    @objc(setConsentGranted:)
    public static func setConsentGranted(_ granted: Bool) {
        Task { @MainActor in
            Delight.setConsent(granted: granted)
        }
    }

    @objc
    public static func clearLocalData() {
        Task { @MainActor in
            Delight.clearLocalData()
        }
    }

    @objc
    public static func resetDailySuppressionState() {
        Task { @MainActor in
            Delight.resetDailySuppressionState()
        }
    }

    /// Objective-C bridge for showing a reward popup.
    @objc(showRewardPopup:email:userToken:firstName:lastName:ticketTypes:onImpression:onPrimaryClick:onDismiss:onError:)
    public static func showRewardPopup(
        _ orderId: String?,
        email: String?,
        userToken: String?,
        firstName: String?,
        lastName: String?,
        ticketTypes: [String],
        onImpression: ((NSString?) -> Void)?,
        onPrimaryClick: ((NSString?) -> Void)?,
        onDismiss: (() -> Void)?,
        onError: ((NSString) -> Void)?
    ) {
        let payload = DelightRequestPayload(
            orderId: orderId,
            email: email,
            userToken: userToken,
            firstName: firstName,
            lastName: lastName,
            ticketTypes: ticketTypes
        )

        var callbacks = DelightCallbacks()
        callbacks.onImpression = { rewardId in
            onImpression?(rewardId as NSString?)
        }
        callbacks.onPrimaryClick = { rewardId in
            onPrimaryClick?(rewardId as NSString?)
        }
        callbacks.onDismiss = {
            onDismiss?()
        }
        callbacks.onError = { message in
            onError?(message as NSString)
        }

        Task { @MainActor in
            Delight.showRewardPopup(payload, callbacks: callbacks)
        }
    }

    @available(*, deprecated, renamed: "showRewardPopup(_:email:userToken:firstName:lastName:ticketTypes:onImpression:onPrimaryClick:onDismiss:onError:)")
    @objc(showReward:email:userToken:firstName:lastName:ticketTypes:onImpression:onPrimaryClick:onDismiss:onError:)
    public static func showReward(
        _ orderId: String?,
        email: String?,
        userToken: String?,
        firstName: String?,
        lastName: String?,
        ticketTypes: [String],
        onImpression: ((NSString?) -> Void)?,
        onPrimaryClick: ((NSString?) -> Void)?,
        onDismiss: (() -> Void)?,
        onError: ((NSString) -> Void)?
    ) {
        showRewardPopup(
            orderId,
            email: email,
            userToken: userToken,
            firstName: firstName,
            lastName: lastName,
            ticketTypes: ticketTypes,
            onImpression: onImpression,
            onPrimaryClick: onPrimaryClick,
            onDismiss: onDismiss,
            onError: onError
        )
    }

    /// Objective-C bridge for dismissing popup.
    @objc
    public static func dismiss() {
        Task { @MainActor in
            Delight.dismiss()
        }
    }
}
