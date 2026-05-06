import XCTest
#if SWIFT_PACKAGE
@testable import DelightSDK
#else
@testable import sdk
#endif

final class DelightSDKTests: XCTestCase {
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

    func testSelectConfigSuppresses18PlusForChildTicketType() {
        let config = makeConfig(
            rewards: [
                makeReward(id: "adult-18", ticketType: "adult", ageRequirement: "18+"),
                makeReward(id: "child-safe", ticketType: "child", ageRequirement: "none")
            ]
        )
        let payload = makePayload(ticketTypes: ["child"])

        let selected = DelightRewardSelectionService.selectConfig(
            from: config,
            payload: payload,
            ignoreLocalRulesForTesting: true,
            ignoreCooldownForLocalDevelopment: true
        )

        XCTAssertEqual(selected?.popup?.rewards?.first?.id, "child-safe")
    }

    func testSelectConfigPrioritizesMatchingTicketType() {
        let config = makeConfig(
            rewards: [
                makeReward(id: "adult-first", ticketType: "adult"),
                makeReward(id: "student-second", ticketType: "student")
            ]
        )
        let payload = makePayload(ticketTypes: ["student"])

        let selected = DelightRewardSelectionService.selectConfig(
            from: config,
            payload: payload,
            ignoreLocalRulesForTesting: true,
            ignoreCooldownForLocalDevelopment: true
        )

        XCTAssertEqual(selected?.popup?.rewards?.first?.id, "student-second")
    }

    func testSelectConfigReturnsNilWhenAllRewardsHidden() {
        let config = makeConfig(
            rewards: [
                makeReward(id: "hidden-1", show: false),
                makeReward(id: "hidden-2", show: false)
            ]
        )
        let payload = makePayload(ticketTypes: ["adult"])

        let selected = DelightRewardSelectionService.selectConfig(
            from: config,
            payload: payload,
            ignoreLocalRulesForTesting: true,
            ignoreCooldownForLocalDevelopment: true
        )

        XCTAssertNil(selected)
    }

    func testSelectConfigFallsBackToConfigOrderWhenNoTicketTypeMatch() {
        let config = makeConfig(
            rewards: [
                makeReward(id: "adult-first", ticketType: "adult"),
                makeReward(id: "student-second", ticketType: "student")
            ]
        )
        let payload = makePayload(ticketTypes: ["concession"])

        let selected = DelightRewardSelectionService.selectConfig(
            from: config,
            payload: payload,
            ignoreLocalRulesForTesting: true,
            ignoreCooldownForLocalDevelopment: true
        )

        XCTAssertEqual(selected?.popup?.rewards?.first?.id, "adult-first")
    }
}

private func makeConfig(rewards: [DelightPopupRewardDTO]) -> DelightConfigDTO {
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
        )
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

private func makePayload(ticketTypes: [String]) -> DelightRequestPayload {
    DelightRequestPayload(
        orderId: UUID().uuidString,
        email: nil,
        userToken: UUID().uuidString,
        firstName: nil,
        lastName: nil,
        ticketTypes: ticketTypes
    )
}
