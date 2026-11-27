import XCTest
#if SWIFT_PACKAGE
@testable import DelightSDK
#else
@testable import sdk
#endif

@MainActor
final class DelightGwrPresentIconTests: XCTestCase {
    override func tearDown() {
        Delight.resetPopupControllerForTesting()
        DelightPopupSessionStore.clear()
        super.tearDown()
    }

    func testGwrMinimisesAgainAndReportsTheSameRewardId() {
        let minimised = RewardIdLog()
        let tapped = RewardIdLog()
        let errors = RewardIdLog()
        let controller = prepare(
            host: "GWR",
            brand: "gwr-com",
            minimised: minimised,
            tapped: tapped,
            errors: errors
        )

        controller.minimize()
        XCTAssertTrue(controller.isMinimized)
        XCTAssertFalse(controller.closeButtonShowsDismiss)
        XCTAssertEqual(minimised.values, ["reward-42"])
        XCTAssertTrue(errors.values.isEmpty)

        controller.expandFromMinimized()
        XCTAssertFalse(controller.isMinimized)
        XCTAssertFalse(controller.closeButtonShowsDismiss)
        XCTAssertEqual(controller.closeButtonAction(for: readyConfig(host: "GWR", brand: "gwr-com")), .minimize)
        XCTAssertEqual(tapped.values, ["reward-42"])

        controller.minimize()
        XCTAssertTrue(controller.isMinimized)
        XCTAssertFalse(controller.closeButtonShowsDismiss)
        XCTAssertEqual(minimised.values, ["reward-42", "reward-42"])
        XCTAssertTrue(errors.values.isEmpty)
    }

    func testGwrGiftIconDoesNotReturnAfterThePageIsLeft() {
        let controller = prepare(host: "GWR", brand: "gwr-com")
        controller.minimize()
        XCTAssertNotNil(DelightPopupSessionStore.load())

        controller.retirePresentIconForPageLeave()
        XCTAssertFalse(controller.isMinimized)
        XCTAssertFalse(controller.isPresented)
        XCTAssertNil(DelightPopupSessionStore.load())

        controller.handleEnterForegroundForLifecycle()
        XCTAssertFalse(controller.isMinimized)
        XCTAssertNil(DelightPopupSessionStore.load())
    }

    func testGwrPageLeaveDoesNotCallDismissOrError() {
        let dismissed = Flag()
        let errors = RewardIdLog()
        let controller = prepare(host: "GWR", brand: "gwr-com", errors: errors, dismissed: dismissed)
        controller.minimize()
        controller.retirePresentIconForPageLeave()
        XCTAssertFalse(dismissed.value)
        XCTAssertTrue(errors.values.isEmpty)
    }

    func testStagecoachStillDismissesOnReopenAndIgnoresTheGwrCallbacks() {
        let minimised = RewardIdLog()
        let tapped = RewardIdLog()
        let controller = prepare(
            host: "Stagecoach",
            brand: "stagecoachbus-com",
            minimised: minimised,
            tapped: tapped
        )

        controller.minimize()
        XCTAssertTrue(controller.isMinimized)
        XCTAssertTrue(minimised.values.isEmpty)
        controller.retirePresentIconForPageLeave()
        XCTAssertTrue(controller.isMinimized)

        controller.expandFromMinimized()
        XCTAssertFalse(controller.isMinimized)
        XCTAssertTrue(controller.closeButtonShowsDismiss)
        XCTAssertEqual(
            controller.closeButtonAction(for: readyConfig(host: "Stagecoach", brand: "stagecoachbus-com")),
            .dismiss
        )
        XCTAssertTrue(tapped.values.isEmpty)
    }

    func testCallbackNamesMatchOnBothPlatforms() {
        let callbacks = DelightCallbacks(
            onOverlayMinimised: { _ in },
            onGiftIconTapped: { _ in }
        )
        XCTAssertNotNil(callbacks.onOverlayMinimised)
        XCTAssertNotNil(callbacks.onGiftIconTapped)
    }

    private func prepare(
        host: String,
        brand: String,
        minimised: RewardIdLog = RewardIdLog(),
        tapped: RewardIdLog = RewardIdLog(),
        errors: RewardIdLog = RewardIdLog(),
        dismissed: Flag = Flag()
    ) -> DelightPopupController {
        let controller = DelightPopupController.shared
        let config = readyConfig(host: host, brand: brand)
        controller.setInitializedBrandName(brand)
        controller.payload = DelightRequestPayload(orderId: "booking-1", email: nil)
        controller.callbacks = DelightCallbacks(
            onDismiss: { dismissed.value = true },
            onError: { errors.values.append($0) },
            onOverlayMinimised: { minimised.values.append($0) },
            onGiftIconTapped: { tapped.values.append($0) }
        )
        controller.config = config
        controller.state = .ready(config, DelightPopupTheme.fromBrandTheme(nil), "reward-42")
        controller.carouselRewardIndex = 0
        return controller
    }

    private func readyConfig(host: String, brand: String) -> DelightConfigDTO {
        DelightConfigDTO(
            partnerId: "test-partner",
            partnerLogo: nil,
            hostDisplayName: host,
            apiUrl: "https://api.rewardsbag.com",
            language: "en",
            popup: DelightPopupSectionDTO(
                enabled: true,
                defaultLocale: "en",
                locales: nil,
                theme: nil,
                rewards: [
                    DelightPopupRewardDTO(
                        id: "reward-42",
                        show: true,
                        ctaUrl: nil,
                        postPopupMobileImage: nil,
                        postPopupWebImage: nil,
                        logo: nil,
                        partnerTermsUrl: nil,
                        privacyPolicyUrl: nil,
                        poweredByUrl: nil,
                        locales: nil,
                        ticketType: nil,
                        ageRequirement: nil
                    )
                ],
                enablePresentIcon: true
            ),
            suppressionRules: nil,
            brandName: brand
        )
    }
}

private final class RewardIdLog {
    var values: [String] = []
}

private final class Flag {
    var value = false
}
