import XCTest
#if SWIFT_PACKAGE
@testable import DelightSDK
#else
@testable import sdk
#endif

final class DelightSDKTests: XCTestCase {
    override func tearDown() {
        super.tearDown()
        DelightRewardSelectionService.clearLocalData()
        UserDefaults.standard.removeObject(forKey: "delight.sdk.local-user-token")
    }

    func testResolvedRewardsFiltersHiddenRewards() {
        let config = makeConfig(
            rewards: [
                makeReward(id: "visible", show: true),
                makeReward(id: "hidden", show: false)
            ]
        )

        let ids = config.resolvedRewards.compactMap(\.id)
        XCTAssertEqual(ids, ["visible"])
    }

    func testDailyCooldownBlocksSecondSlotUntilConfiguredHours() {
        let userToken = UUID().uuidString.lowercased()
        let rules = makeSuppressionRules(dailyCooldownHours: 5)
        let config = makeConfig(
            suppressionRules: rules,
            rewards: [
                makeReward(id: "A", ticketType: "child"),
                makeReward(id: "B", ticketType: "child"),
                makeReward(id: "P", ticketType: "young-person")
            ]
        )

        let morning = Date()
        recordImpression(
            config: config,
            payload: makePayload(orderId: "order-1", ticketTypes: ["child"], userToken: userToken),
            rewardId: "A",
            at: morning
        )

        let duringCooldown = select(
            config: config,
            payload: makePayload(orderId: "order-2", ticketTypes: ["young-person"], userToken: userToken),
            now: morning.addingTimeInterval(3 * 3600)
        )
        XCTAssertNil(duringCooldown)

        let afterCooldown = select(
            config: config,
            payload: makePayload(orderId: "order-3", ticketTypes: ["young-person"], userToken: userToken),
            now: morning.addingTimeInterval(6 * 3600)
        )
        XCTAssertEqual(afterCooldown?.popup?.rewards?.first?.id, "P")
    }

    func testMixedBasketUsesCombinedRewardPoolFromAllTicketTypes() {
        let config = makeConfig(
            rewards: [
                makeReward(id: "A", ticketType: "child"),
                makeReward(id: "B", ticketType: "child"),
                makeReward(id: "X", ticketType: "adult"),
                makeReward(id: "Y", ticketType: "adult")
            ]
        )

        let childThenAdult = select(
            config: config,
            payload: makePayload(
                orderId: "order-1",
                ticketTypes: ["child", "adult"],
                userToken: UUID().uuidString.lowercased()
            )
        )
        XCTAssertEqual(childThenAdult?.popup?.rewards?.first?.id, "A")

        let adultThenChild = select(
            config: config,
            payload: makePayload(
                orderId: "order-2",
                ticketTypes: ["adult", "child"],
                userToken: UUID().uuidString.lowercased()
            )
        )
        XCTAssertEqual(adultThenChild?.popup?.rewards?.first?.id, "X")
    }

    func testMixedBasketFallsThroughToNextTicketTypeWhenEarlierRewardsSuppressed() {
        let userToken = UUID().uuidString.lowercased()
        let config = makeConfig(
            rewards: [
                makeReward(id: "A", ticketType: "child"),
                makeReward(id: "B", ticketType: "child"),
                makeReward(id: "X", ticketType: "adult")
            ]
        )

        DelightRewardSelectionService.recordClick(
            payload: makePayload(orderId: "prior-1", ticketTypes: ["child"], userToken: userToken),
            rewardId: "A"
        )
        DelightRewardSelectionService.recordClick(
            payload: makePayload(orderId: "prior-2", ticketTypes: ["child"], userToken: userToken),
            rewardId: "B"
        )

        let selected = select(
            config: config,
            payload: makePayload(
                orderId: "order-1",
                ticketTypes: ["child", "adult"],
                userToken: userToken
            )
        )
        XCTAssertEqual(selected?.popup?.rewards?.first?.id, "X")
    }

    func testSecondDailyRewardMustDifferFromFirst() {
        let userToken = UUID().uuidString.lowercased()
        let rules = makeSuppressionRules(maxRewardsPerUserPerDay: 2)
        let config = makeConfig(
            suppressionRules: rules,
            rewards: [
                makeReward(id: "first", ticketType: "adult"),
                makeReward(id: "second", ticketType: "adult")
            ]
        )

        let firstPayload = makePayload(orderId: "order-1", ticketTypes: ["adult"], userToken: userToken)
        recordImpression(config: config, payload: firstPayload, rewardId: "first")

        let secondPayload = makePayload(orderId: "order-2", ticketTypes: ["adult"], userToken: userToken)
        let selected = select(config: config, payload: secondPayload)

        XCTAssertEqual(selected?.popup?.rewards?.first?.id, "second")
    }

    func testSameTransactionReturnsSameRewardWithoutConsumingSecondDailySlot() {
        let userToken = UUID().uuidString.lowercased()
        let config = makeConfig(
            rewards: [
                makeReward(id: "first", ticketType: "adult"),
                makeReward(id: "second", ticketType: "adult")
            ]
        )
        let payload = makePayload(orderId: "order-1", ticketTypes: ["adult"], userToken: userToken)

        let firstSelection = select(config: config, payload: payload)
        let secondSelection = select(config: config, payload: payload)

        XCTAssertEqual(firstSelection?.popup?.rewards?.first?.id, "first")
        XCTAssertEqual(secondSelection?.popup?.rewards?.first?.id, "first")
    }

    func testClickSuppressionUsesConfigPeriod() {
        let userToken = UUID().uuidString.lowercased()
        let rules = makeSuppressionRules(suppressionPeriodAfterClickDays: 45)
        let config = makeConfig(
            suppressionRules: rules,
            rewards: [
                makeReward(id: "clicked", ticketType: "adult"),
                makeReward(id: "next", ticketType: "adult")
            ]
        )
        let payload = makePayload(orderId: "order-1", ticketTypes: ["adult"], userToken: userToken)

        DelightRewardSelectionService.recordClick(payload: payload, rewardId: "clicked")

        let selected = select(config: config, payload: makePayload(orderId: "order-2", ticketTypes: ["adult"], userToken: userToken))
        XCTAssertEqual(selected?.popup?.rewards?.first?.id, "next")
    }

    func testFatigueSuppressesRewardAfterConfiguredUnengagedImpressions() {
        let userToken = UUID().uuidString.lowercased()
        let rules = makeSuppressionRules(
            maxImpressionsPerRewardWithoutEngagement: 3,
            restPeriodAfterNoEngagementDays: 21
        )
        let config = makeConfig(
            suppressionRules: rules,
            rewards: [
                makeReward(id: "tired", ticketType: "adult"),
                makeReward(id: "fresh", ticketType: "adult")
            ]
        )

        for index in 1...3 {
            let payload = makePayload(orderId: "day-\(index)", ticketTypes: ["adult"], userToken: userToken)
            recordImpression(config: config, payload: payload, rewardId: "tired")
        }

        let selected = select(
            config: config,
            payload: makePayload(orderId: "day-4", ticketTypes: ["adult"], userToken: userToken)
        )

        XCTAssertEqual(selected?.popup?.rewards?.first?.id, "fresh")
    }

    func testFatigueSuppressesOnlyRewardWhenNoAlternativesRemain() {
        let userToken = UUID().uuidString.lowercased()
        let rules = makeSuppressionRules(
            maxImpressionsPerRewardWithoutEngagement: 3,
            restPeriodAfterNoEngagementDays: 21
        )
        let config = makeConfig(
            suppressionRules: rules,
            rewards: [makeReward(id: "only", ticketType: "adult")]
        )

        for index in 1...3 {
            recordImpression(
                config: config,
                payload: makePayload(orderId: "order-\(index)", ticketTypes: ["adult"], userToken: userToken),
                rewardId: "only"
            )
        }

        let selected = select(
            config: config,
            payload: makePayload(orderId: "order-4", ticketTypes: ["adult"], userToken: userToken)
        )

        XCTAssertNil(selected)
    }

    func testFirstDailyRewardUsesFirstEligibleInTicketTypeList() {
        let config = makeConfig(
            rewards: [
                makeReward(id: "A", ticketType: "child"),
                makeReward(id: "B", ticketType: "child"),
                makeReward(id: "C", ticketType: "child")
            ]
        )

        let selected = select(
            config: config,
            payload: makePayload(orderId: "order-1", ticketTypes: ["child"], userToken: UUID().uuidString.lowercased())
        )

        XCTAssertEqual(selected?.popup?.rewards?.first?.id, "A")
    }

    func testSelectsFromTicketTypeOrderOnSameDay() {
        let userToken = UUID().uuidString.lowercased()
        let config = makeConfig(
            rewards: [
                makeReward(id: "A", ticketType: "child"),
                makeReward(id: "B", ticketType: "child"),
                makeReward(id: "X", ticketType: "adult"),
                makeReward(id: "Y", ticketType: "adult")
            ]
        )

        recordImpression(
            config: config,
            payload: makePayload(orderId: "day1-order-1", ticketTypes: ["child"], userToken: userToken),
            rewardId: "A"
        )

        let day1Adult = select(
            config: config,
            payload: makePayload(orderId: "day1-order-2", ticketTypes: ["adult"], userToken: userToken)
        )
        XCTAssertEqual(day1Adult?.popup?.rewards?.first?.id, "X")

        recordImpression(
            config: config,
            payload: makePayload(orderId: "day1-order-2", ticketTypes: ["adult"], userToken: userToken),
            rewardId: "X"
        )

        let day1Third = select(
            config: config,
            payload: makePayload(orderId: "day1-order-3", ticketTypes: ["child"], userToken: userToken)
        )
        XCTAssertNil(day1Third)
    }

    func testSecondChildRewardAdvancesWithinChildList() {
        let userToken = UUID().uuidString.lowercased()
        let config = makeConfig(
            rewards: [
                makeReward(id: "A", ticketType: "child"),
                makeReward(id: "B", ticketType: "child"),
                makeReward(id: "X", ticketType: "adult")
            ]
        )

        recordImpression(
            config: config,
            payload: makePayload(orderId: "order-1", ticketTypes: ["child"], userToken: userToken),
            rewardId: "A"
        )

        let secondChild = select(
            config: config,
            payload: makePayload(orderId: "order-2", ticketTypes: ["child"], userToken: userToken)
        )
        XCTAssertEqual(secondChild?.popup?.rewards?.first?.id, "B")
    }

    func testMonthlyImpressionCapBlocksSelection() {
        let userToken = UUID().uuidString.lowercased()
        let rules = makeSuppressionRules(maxImpressionsPerUserPerMonth: 15)
        let config = makeConfig(
            suppressionRules: rules,
            rewards: [makeReward(id: "only", ticketType: "adult")]
        )

        for index in 0..<15 {
            recordImpression(
                config: config,
                payload: makePayload(orderId: "order-\(index)", ticketTypes: ["adult"], userToken: userToken),
                rewardId: "only"
            )
        }

        let selected = select(
            config: config,
            payload: makePayload(orderId: "order-final", ticketTypes: ["adult"], userToken: userToken)
        )

        XCTAssertNil(selected)
    }

    func testReopenedTransactionDoesNotRecordSecondImpression() {
        let userToken = UUID().uuidString.lowercased()
        let config = makeConfig(rewards: [makeReward(id: "only", ticketType: "adult")])
        let payload = makePayload(orderId: "order-1", ticketTypes: ["adult"], userToken: userToken)

        DelightRewardSelectionService.recordVisibleImpression(
            payload: payload,
            rewardId: "only",
            at: Date(),
            suppressionRules: config.suppressionRules
        )
        DelightRewardSelectionService.recordVisibleImpression(
            payload: payload,
            rewardId: "only",
            at: Date(),
            suppressionRules: config.suppressionRules
        )

        let selected = select(
            config: config,
            payload: makePayload(orderId: "order-2", ticketTypes: ["adult"], userToken: userToken)
        )
        XCTAssertEqual(selected?.popup?.rewards?.first?.id, "only")
    }

    func testRewardHistoryPersistsWhenConfigRotatesOffAndBack() {
        let userToken = UUID().uuidString.lowercased()
        let rules = makeSuppressionRules(
            maxImpressionsPerRewardWithoutEngagement: 3,
            suppressionPeriodAfterClickDays: 45
        )

        let weekOneConfig = makeConfig(
            suppressionRules: rules,
            rewards: [
                makeReward(id: "reward-a", ticketType: "child"),
                makeReward(id: "reward-b", ticketType: "child")
            ]
        )
        let weekTwoConfig = makeConfig(
            suppressionRules: rules,
            rewards: [makeReward(id: "reward-x", ticketType: "child")]
        )
        let weekThreeConfig = makeConfig(
            suppressionRules: rules,
            rewards: [
                makeReward(id: "reward-a", ticketType: "child"),
                makeReward(id: "reward-b", ticketType: "child")
            ]
        )

        DelightRewardSelectionService.recordClick(
            payload: makePayload(orderId: "order-1", ticketTypes: ["child"], userToken: userToken),
            rewardId: "reward-a"
        )

        for index in 2...3 {
            recordImpression(
                config: weekOneConfig,
                payload: makePayload(orderId: "order-\(index)", ticketTypes: ["child"], userToken: userToken),
                rewardId: "reward-b"
            )
        }

        let whileRotatedOff = select(
            config: weekTwoConfig,
            payload: makePayload(orderId: "order-7", ticketTypes: ["child"], userToken: userToken)
        )
        XCTAssertEqual(whileRotatedOff?.popup?.rewards?.first?.id, "reward-x")

        let whenRotatedBack = select(
            config: weekThreeConfig,
            payload: makePayload(orderId: "order-8", ticketTypes: ["child"], userToken: userToken)
        )
        XCTAssertEqual(whenRotatedBack?.popup?.rewards?.first?.id, "reward-b")
    }

    func testResetDailySuppressionStateAllowsAnotherDailyCycle() {
        let userToken = UUID().uuidString.lowercased()
        let config = makeConfig(
            rewards: [
                makeReward(id: "A", ticketType: "child"),
                makeReward(id: "B", ticketType: "child"),
                makeReward(id: "X", ticketType: "adult")
            ]
        )

        recordImpression(
            config: config,
            payload: makePayload(orderId: "order-1", ticketTypes: ["child"], userToken: userToken),
            rewardId: "A"
        )
        recordImpression(
            config: config,
            payload: makePayload(orderId: "order-2", ticketTypes: ["adult"], userToken: userToken),
            rewardId: "X"
        )

        let blockedThird = select(
            config: config,
            payload: makePayload(orderId: "order-3", ticketTypes: ["child"], userToken: userToken)
        )
        XCTAssertNil(blockedThird)

        DelightRewardSelectionService.resetDailySuppressionState()

        let afterReset = select(
            config: config,
            payload: makePayload(orderId: "order-4", ticketTypes: ["child"], userToken: userToken)
        )
        XCTAssertEqual(afterReset?.popup?.rewards?.first?.id, "A")
    }

    func testResetDailySuppressionStatePreservesFatigueHistory() {
        let userToken = UUID().uuidString.lowercased()
        let rules = makeSuppressionRules(
            maxImpressionsPerRewardWithoutEngagement: 3,
            restPeriodAfterNoEngagementDays: 21
        )
        let config = makeConfig(
            suppressionRules: rules,
            rewards: [
                makeReward(id: "A", ticketType: "adult"),
                makeReward(id: "B", ticketType: "adult")
            ]
        )

        for day in 1...3 {
            if day > 1 {
                DelightRewardSelectionService.resetDailySuppressionState()
            }
            recordImpression(
                config: config,
                payload: makePayload(orderId: "day\(day)-order-1", ticketTypes: ["adult"], userToken: userToken),
                rewardId: "A"
            )
        }

        DelightRewardSelectionService.resetDailySuppressionState()

        let afterFatigue = select(
            config: config,
            payload: makePayload(orderId: "day4-order-1", ticketTypes: ["adult"], userToken: userToken)
        )
        XCTAssertEqual(afterFatigue?.popup?.rewards?.first?.id, "B")
    }
}

private func select(
    config: DelightConfigDTO,
    payload: DelightRequestPayload,
    now: Date = Date()
) -> DelightConfigDTO? {
    DelightRewardSelectionService.selectConfig(
        from: config,
        payload: payload,
        now: now
    )
}

private func recordImpression(
    config: DelightConfigDTO,
    payload: DelightRequestPayload,
    rewardId: String,
    at date: Date = Date()
) {
    DelightRewardSelectionService.recordVisibleImpression(
        payload: payload,
        rewardId: rewardId,
        at: date,
        suppressionRules: config.suppressionRules
    )
}

private func makeSuppressionRules(
    maxImpressionsPerUserPerMonth: Int = 15,
    maxRewardsPerUserPerDay: Int = 2,
    dailyCooldownHours: Int = 0,
    maxImpressionsPerRewardWithoutEngagement: Int = 3,
    restPeriodAfterNoEngagementDays: Int = 21,
    suppressionPeriodAfterClickDays: Int = 45,
    retentionDays: Int = 90
) -> DelightSuppressionRulesDTO {
    DelightSuppressionRulesDTO(
        maxImpressionsPerUserPerMonth: maxImpressionsPerUserPerMonth,
        maxRewardsPerUserPerDay: maxRewardsPerUserPerDay,
        dailyCooldownHours: dailyCooldownHours,
        maxImpressionsPerRewardWithoutEngagement: maxImpressionsPerRewardWithoutEngagement,
        restPeriodAfterNoEngagementDays: restPeriodAfterNoEngagementDays,
        suppressionPeriodAfterClickDays: suppressionPeriodAfterClickDays,
        retentionDays: retentionDays
    )
}

private func makeConfig(
    suppressionRules: DelightSuppressionRulesDTO? = nil,
    rewards: [DelightPopupRewardDTO]
) -> DelightConfigDTO {
    DelightConfigDTO(
        partnerId: "test-partner",
        partnerLogo: nil,
        apiUrl: "https://api.rewardsbag.com",
        language: "en",
        popup: DelightPopupSectionDTO(
            enabled: true,
            defaultLocale: "en",
            locales: nil,
            theme: nil,
            rewards: rewards
        ),
        suppressionRules: suppressionRules ?? makeSuppressionRules()
    )
}

private func makeReward(
    id: String,
    show: Bool = true,
    ticketType: String? = nil,
    ageRequirement: String? = nil
) -> DelightPopupRewardDTO {
    DelightPopupRewardDTO(
        id: id,
        show: show,
        ctaUrl: nil,
        postPopupMobileImage: nil,
        postPopupWebImage: nil,
        logo: nil,
        partnerTermsUrl: nil,
        privacyPolicyUrl: nil,
        poweredByUrl: nil,
        locales: nil,
        ticketType: ticketType,
        ageRequirement: ageRequirement
    )
}

private func makePayload(
    orderId: String,
    ticketTypes: [String],
    userToken: String
) -> DelightRequestPayload {
    DelightRequestPayload(
        orderId: orderId,
        email: nil,
        userToken: userToken,
        firstName: nil,
        lastName: nil,
        ticketTypes: ticketTypes
    )
}
