import XCTest
#if SWIFT_PACKAGE
@testable import DelightSDK
#else
@testable import sdk
#endif

/// Fail-safe parity with Delight Android SDK v1.1.2 (8 cases). See `DelightFailSafeReport`.
final class DelightFailSafeTests: DelightFailSafeTestCase {

    // MARK: Config

    @MainActor
    func test404Config_showNothing_noThrow() async {
        let spec = DelightFailSafeReport.catalog[0]
        await self.runFailSafeCase(spec) {
            let session = MockDelightURLProtocol.makeSession()

            do {
                _ = try await DelightConfigService.fetchConfig(
                    brandName: "missing-brand",
                    cdnBaseURL: URL(string: "https://cdn.test")!,
                    session: session
                )
                XCTFail("Expected fetch to fail")
            } catch {
                XCTAssertTrue(error is URLError)
            }

            DelightConfigService.testingURLSession = session
            await Delight.initialize(
                brandName: "missing-brand",
                cdnBaseURL: URL(string: "https://cdn.test")!,
                useBundledConfig: false,
                consentGranted: true
            )
            DelightConfigService.testingURLSession = nil

            Delight.showRewardPopup(
                failSafeMakePayload(orderId: "order-404", ticketTypes: ["adult"]),
                callbacks: DelightCallbacks(onError: { _ in XCTFail("Host onError must not fire") })
            )
            self.assertShowNothingNoThrow()
            XCTAssertTrue(DelightSessionGuard.isDisabledForSession)
        }
    }

    @MainActor
    func testMalformedJSON_showNothing_noThrow() async {
        let spec = DelightFailSafeReport.catalog[1]
        await self.runFailSafeCase(spec) {
            MockDelightURLProtocol.responseHandler = { _ in
                (
                    HTTPURLResponse(
                        url: URL(string: "https://cdn.test/configs/bad.json")!,
                        statusCode: 200,
                        httpVersion: nil,
                        headerFields: nil
                    )!,
                    Data("{ not-json".utf8)
                )
            }

            let session = MockDelightURLProtocol.makeSession()
            do {
                _ = try await DelightConfigService.fetchConfig(
                    brandName: "bad",
                    cdnBaseURL: URL(string: "https://cdn.test")!,
                    session: session
                )
                XCTFail("Expected decode failure")
            } catch {
                XCTAssertTrue(error is DecodingError)
            }

            DelightConfigService.testingURLSession = session
            await Delight.initialize(
                brandName: "bad",
                cdnBaseURL: URL(string: "https://cdn.test")!,
                useBundledConfig: false,
                consentGranted: true
            )
            DelightConfigService.testingURLSession = nil

            Delight.showRewardPopup(
                failSafeMakePayload(orderId: "order-bad-json", ticketTypes: ["adult"]),
                callbacks: DelightCallbacks(onError: { _ in })
            )
            await failSafeWaitUntil { !failSafePopupStateIsLoading(self.controller.state) }
            self.assertShowNothingNoThrow()
        }
    }

    @MainActor
    func testEmptyRewards_showNothing_noThrow() async {
        let spec = DelightFailSafeReport.catalog[2]
        await self.runFailSafeCase(spec) {
            let config = failSafeMakeConfig(rewards: [])
            Delight.loadConfigForTesting(brandName: "stagecoachbus-com", config: config)

            Delight.showRewardPopup(
                failSafeMakePayload(orderId: "order-empty", ticketTypes: ["adult"]),
                callbacks: DelightCallbacks(onError: { _ in })
            )
            await failSafeWaitUntil { !failSafePopupStateIsLoading(self.controller.state) }
            self.assertShowNothingNoThrow()
        }
    }

    // MARK: Render isolation

    @MainActor
    func testRenderThrow_swallowed_hostNotCrashed() async {
        let spec = DelightFailSafeReport.catalog[3]
        await self.runFailSafeCase(spec) {
            DelightRuntimeTestFlags.suppressTemplateBody = true
            let config = failSafeMakeConfig(rewards: [failSafeMakeReward(id: "only", ticketType: "adult")])
            Delight.loadConfigForTesting(brandName: "stagecoachbus-com", config: config)

            Delight.showRewardPopup(
                failSafeMakePayload(orderId: "order-render", ticketTypes: ["adult"]),
                callbacks: DelightCallbacks()
            )
            await failSafeWaitUntil {
                if case .hidden = self.controller.state { return true }
                if case .ready = self.controller.state { return true }
                return !failSafePopupStateIsLoading(self.controller.state)
            }
            self.assertShowNothingNoThrow()
        }
    }

    @MainActor
    func testInvalidRewardConfig_missingHeadlineAndImage_showNothing() async {
        let badReward = DelightPopupRewardDTO(
            id: "bad",
            show: true,
            ctaUrl: nil,
            postPopupMobileImage: nil,
            postPopupWebImage: nil,
            logo: nil,
            partnerTermsUrl: nil,
            privacyPolicyUrl: nil,
            poweredByUrl: nil,
            locales: nil,
            ticketType: "adult",
            ageRequirement: nil
        )
        Delight.loadConfigForTesting(
            brandName: "stagecoachbus-com",
            config: failSafeMakeConfig(rewards: [badReward])
        )
        Delight.showRewardPopup(
            failSafeMakePayload(orderId: "order-invalid", ticketTypes: ["adult"]),
            callbacks: DelightCallbacks(onError: { _ in XCTFail("Host onError must not fire") })
        )
        await failSafeWaitUntil { !failSafePopupStateIsLoading(self.controller.state) }
        self.assertShowNothingNoThrow()
    }

    // MARK: Native lifecycle

    @MainActor
    func testDismissImmediately_unmountBeforeSettle_noThrow() async {
        let spec = DelightFailSafeReport.catalog[4]
        await self.runFailSafeCase(spec) {
            let config = failSafeMakeConfig(rewards: [failSafeMakeReward(id: "only", ticketType: "adult")])
            Delight.loadConfigForTesting(brandName: "stagecoachbus-com", config: config)

            Delight.showRewardPopup(
                failSafeMakePayload(orderId: "order-flash", ticketTypes: ["adult"]),
                callbacks: DelightCallbacks()
            )
            Delight.dismiss()

            if case .hidden = self.controller.state {
                XCTAssertFalse(self.controller.isPresented)
            } else if case .loading = self.controller.state {
                Delight.dismiss()
                if case .hidden = self.controller.state {
                    XCTAssertFalse(self.controller.isPresented)
                }
            }
        }
    }

    @MainActor
    func testRotateMidPopup_configurationChangeDoesNotThrow() async {
        let spec = DelightFailSafeReport.catalog[5]
        await self.runFailSafeCase(spec) {
            let config = failSafeMakeConfig(
                hostDisplayName: "GWR",
                brandName: "gwr-com",
                applyDefaultSuppressionRules: false,
                rewards: [
                    failSafeMakeReward(id: "simplycook", ticketType: ""),
                    failSafeMakeReward(id: "bookbeat", ticketType: "")
                ]
            )
            Delight.loadConfigForTesting(brandName: "gwr-com", config: config)

            Delight.showRewardPopup(
                failSafeMakePayload(orderId: "order-rotate", ticketTypes: nil),
                callbacks: DelightCallbacks()
            )
            await failSafeWaitUntil { !failSafePopupStateIsLoading(self.controller.state) }

            self.controller.carouselRewardIndex = 1
            self.controller.claimedRewardIds = ["simplycook"]
            self.controller.handleInterfaceRotationForLifecycle()

            XCTAssertEqual(self.controller.carouselRewardIndex, 1)
            if case .ready = self.controller.state {
                XCTAssertTrue(self.controller.claimedRewardIds.contains("simplycook"))
            } else {
                XCTFail("Expected ready state after rotation")
            }
        }
    }

    @MainActor
    func testBackgroundMidPopup_stopStartDoesNotThrow() async {
        let spec = DelightFailSafeReport.catalog[6]
        await self.runFailSafeCase(spec) {
            let config = failSafeMakeConfig(rewards: [failSafeMakeReward(id: "only", ticketType: "adult")])
            Delight.loadConfigForTesting(brandName: "stagecoachbus-com", config: config)

            Delight.showRewardPopup(
                failSafeMakePayload(orderId: "order-bg", ticketTypes: ["adult"]),
                callbacks: DelightCallbacks()
            )
            await failSafeWaitUntil { !failSafePopupStateIsLoading(self.controller.state) }

            self.controller.handleEnterBackgroundForLifecycle()
            self.controller.handleEnterForegroundForLifecycle()

            if case .ready = self.controller.state {
                XCTAssertTrue(self.controller.isPresented)
            } else {
                XCTFail("Expected ready state after foreground")
            }
        }
    }

    @MainActor
    func testProcessDeathAndRestore_sessionReset_reShowDoesNotThrow() async {
        let spec = DelightFailSafeReport.catalog[7]
        await self.runFailSafeCase(spec) {
            let config = failSafeMakeConfig(
                hostDisplayName: "GWR",
                brandName: "gwr-com",
                applyDefaultSuppressionRules: false,
                rewards: [
                    failSafeMakeReward(id: "simplycook", ticketType: ""),
                    failSafeMakeReward(id: "bookbeat", ticketType: "")
                ]
            )
            Delight.loadConfigForTesting(brandName: "gwr-com", config: config)

            Delight.showRewardPopup(
                failSafeMakePayload(orderId: "order-restore", ticketTypes: nil),
                callbacks: DelightCallbacks()
            )
            await failSafeWaitUntil { !failSafePopupStateIsLoading(self.controller.state) }

            self.controller.carouselRewardIndex = 1
            self.controller.persistSessionSnapshot()

            Delight.resetPopupControllerForTesting()
            DelightPopupSessionStore.clear()
            Delight.loadConfigForTesting(brandName: "gwr-com", config: config)

            Delight.showRewardPopup(
                failSafeMakePayload(orderId: "order-restore-new", ticketTypes: nil),
                callbacks: DelightCallbacks()
            )
            await failSafeWaitUntil { !failSafePopupStateIsLoading(self.controller.state) }

            if case .ready = self.controller.state {
                XCTAssertTrue(self.controller.isPresented)
            } else {
                XCTFail("Expected ready after re-show")
            }
        }
    }

    /// Prints the Android-style report (also emitted automatically after all 8 cases pass).
    func testFailSafeReport_manifestMatchesAndroidLayout() {
        let report = DelightFailSafeReport.formattedReport()
        XCTAssertTrue(report.contains("Delight iOS SDK v1.1.2 — fail-safe test report"))
        XCTAssertTrue(report.contains("Config"))
        XCTAssertTrue(report.contains("Render isolation"))
        XCTAssertTrue(report.contains("Native lifecycle"))
        XCTAssertTrue(report.contains("process death and restore"))
        XCTAssertTrue(report.contains("[PASS]") || report.contains("[SKIP]") || report.contains("[FAIL]"))
    }
}
