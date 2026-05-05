import Foundation

@objcMembers
public final class DelightObjC: NSObject {
    /// Objective-C bridge for async SDK initialization.
    /// Completion returns `nil` on success or an NSError on failure.
    @objc(initialize:ignoreLocalRulesForTesting:ignoreCooldownForLocalDevelopment:completion:)
    public static func initialize(
        _ brandName: String,
        ignoreLocalRulesForTesting: Bool,
        ignoreCooldownForLocalDevelopment: Bool,
        completion: ((NSError?) -> Void)?
    ) {
        Task { @MainActor in
            do {
                try await Delight.initialize(
                    brandName: brandName,
                    ignoreLocalRulesForTesting: ignoreLocalRulesForTesting,
                    ignoreCooldownForLocalDevelopment: ignoreCooldownForLocalDevelopment
                )
                completion?(nil)
            } catch {
                completion?(error as NSError)
            }
        }
    }

    /// Objective-C bridge for showing a reward popup.
    @objc(showRewardPopup:email:userToken:firstName:lastName:ticketTypes:onImpression:onPrimaryClick:onDismiss:)
    public static func showRewardPopup(
        _ orderId: String?,
        email: String?,
        userToken: String?,
        firstName: String?,
        lastName: String?,
        ticketTypes: [String],
        onImpression: ((NSString?) -> Void)?,
        onPrimaryClick: ((NSString?) -> Void)?,
        onDismiss: (() -> Void)?
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

        Task { @MainActor in
            Delight.showRewardPopup(payload, callbacks: callbacks)
        }
    }

    @available(*, deprecated, renamed: "showRewardPopup(_:email:userToken:firstName:lastName:ticketTypes:onImpression:onPrimaryClick:onDismiss:)")
    @objc(showReward:email:userToken:firstName:lastName:ticketTypes:onImpression:onPrimaryClick:onDismiss:)
    public static func showReward(
        _ orderId: String?,
        email: String?,
        userToken: String?,
        firstName: String?,
        lastName: String?,
        ticketTypes: [String],
        onImpression: ((NSString?) -> Void)?,
        onPrimaryClick: ((NSString?) -> Void)?,
        onDismiss: (() -> Void)?
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
            onDismiss: onDismiss
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

