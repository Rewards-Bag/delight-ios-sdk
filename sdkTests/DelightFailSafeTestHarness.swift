import Foundation
import XCTest
#if SWIFT_PACKAGE
@testable import DelightSDK
#else
@testable import sdk
#endif

// MARK: - Report (mirrors Delight Android SDK fail-safe report)

enum DelightFailSafeReport {
    struct CaseSpec: Equatable {
        let category: String
        let title: String
        let expectation: String
    }

    static let sdkVersion = "1.1.2"
    static let harnessDescription = "XCTest + @MainActor; run with xcodebuild test (sdkTests) or swift test --filter DelightFailSafe"

    static let catalog: [CaseSpec] = [
        CaseSpec(category: "Config", title: "404 config", expectation: "show nothing, no throw"),
        CaseSpec(category: "Config", title: "malformed JSON", expectation: "show nothing, no throw"),
        CaseSpec(category: "Config", title: "empty rewards", expectation: "show nothing, no throw"),
        CaseSpec(category: "Render isolation", title: "render throw", expectation: "swallowed, host not crashed"),
        CaseSpec(
            category: "Native lifecycle",
            title: "dismiss immediately",
            expectation: "unmount before settle, no throw"
        ),
        CaseSpec(
            category: "Native lifecycle",
            title: "rotate mid-popup",
            expectation: "configuration change does not throw"
        ),
        CaseSpec(
            category: "Native lifecycle",
            title: "background mid-popup",
            expectation: "stop/start does not throw"
        ),
        CaseSpec(
            category: "Native lifecycle",
            title: "process death and restore",
            expectation: "session reset, re-show does not throw"
        )
    ]

    private static var lock = NSLock()
    private static var passedTitles = Set<String>()
    private static var failedTitles = Set<String>()
    private static var didPrintSummary = false

    static func reset() {
        lock.lock()
        passedTitles.removeAll()
        failedTitles.removeAll()
        didPrintSummary = false
        lock.unlock()
    }

    static func recordPass(_ spec: CaseSpec) {
        lock.lock()
        passedTitles.insert(spec.title)
        failedTitles.remove(spec.title)
        lock.unlock()
    }

    static func recordFailure(_ spec: CaseSpec) {
        lock.lock()
        failedTitles.insert(spec.title)
        passedTitles.remove(spec.title)
        lock.unlock()
    }

    static func formattedReport(generatedAt: Date = Date()) -> String {
        lock.lock()
        let passed = passedTitles
        let failed = failedTitles
        lock.unlock()

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        var lines: [String] = []
        lines.append("Delight iOS SDK v\(sdkVersion) — fail-safe test report")
        lines.append("Generated: \(formatter.string(from: generatedAt))")
        lines.append("Runtime: \(ProcessInfo.processInfo.operatingSystemVersionString)")
        lines.append("Harness: \(harnessDescription)")

        let passCount = catalog.filter { passed.contains($0.title) }.count
        let failCount = catalog.filter { failed.contains($0.title) }.count
        let notRun = catalog.count - passCount - failCount
        if notRun > 0 {
            lines.append("Result: \(passCount) passed, \(failCount) failed, \(notRun) not run")
        } else {
            lines.append("Result: \(passCount) passed, \(failCount) failed")
        }
        lines.append("")

        var currentCategory = ""
        for spec in catalog {
            if spec.category != currentCategory {
                currentCategory = spec.category
                lines.append(currentCategory)
            }
            let status: String
            if failed.contains(spec.title) {
                status = "FAIL"
            } else if passed.contains(spec.title) {
                status = "PASS"
            } else {
                status = "SKIP"
            }
            lines.append("  [\(status)] \(spec.title) → \(spec.expectation)")
        }

        lines.append("")
        if failCount == 0, passCount == catalog.count {
            lines.append("ALL FAIL-SAFE CHECKS PASSED.")
        } else {
            lines.append("FAIL-SAFE CHECKS INCOMPLETE OR FAILED.")
        }
        return lines.joined(separator: "\n")
    }

    static func printSummaryIfReady() {
        lock.lock()
        let shouldPrint = !didPrintSummary
        let totalRecorded = passedTitles.count + failedTitles.count
        let complete = totalRecorded >= catalog.count
        if shouldPrint && complete {
            didPrintSummary = true
            lock.unlock()
            let report = formattedReport()
            print("\n\(report)\n")
            if let url = reportOutputURL() {
                try? report.write(to: url, atomically: true, encoding: .utf8)
                print("Wrote fail-safe report to \(url.path)\n")
            }
        } else {
            lock.unlock()
        }
    }

    static func reportOutputURL() -> URL? {
        let env = ProcessInfo.processInfo.environment["DELIGHT_FAILSAFE_REPORT_PATH"]
        if let env, !env.isEmpty {
            return URL(fileURLWithPath: env)
        }
        return FileManager.default.temporaryDirectory
            .appendingPathComponent("delight-ios-fail-safe-report.txt")
    }
}

// MARK: - Base test case

class DelightFailSafeTestCase: XCTestCase {
    @MainActor
    var controller: DelightPopupController { DelightPopupController.shared }

    private var activeSpec: DelightFailSafeReport.CaseSpec?
    private var didFail = false

    @MainActor
    func runFailSafeCase(
        _ spec: DelightFailSafeReport.CaseSpec,
        _ body: @MainActor () async throws -> Void
    ) async rethrows {
        activeSpec = spec
        didFail = false
        do {
            try await body()
            if !didFail {
                DelightFailSafeReport.recordPass(spec)
            }
        } catch {
            DelightFailSafeReport.recordFailure(spec)
            throw error
        }
        DelightFailSafeReport.printSummaryIfReady()
    }

    override func setUp() async throws {
        try await super.setUp()
        await MainActor.run {
            Delight.resetPopupControllerForTesting()
            DelightRewardSelectionService.clearLocalData()
            UserDefaults.standard.removeObject(forKey: "delight.sdk.local-user-token")
            DelightPopupSessionStore.clear()
            DelightRuntimeTestFlags.suppressTemplateBody = false
            DelightConfigService.testingURLSession = nil
            MockDelightURLProtocol.reset()
        }
    }

    override func tearDown() async throws {
        await MainActor.run { [self] in
            if let spec = self.activeSpec, !self.didFail {
                DelightFailSafeReport.recordPass(spec)
            }
            DelightRuntimeTestFlags.suppressTemplateBody = false
            DelightConfigService.testingURLSession = nil
            MockDelightURLProtocol.reset()
            Delight.resetPopupControllerForTesting()
        }
        try await super.tearDown()
    }

    override func record(_ issue: XCTIssue) {
        didFail = true
        if let spec = activeSpec {
            DelightFailSafeReport.recordFailure(spec)
        }
        super.record(issue)
    }

    override class func setUp() {
        super.setUp()
        DelightFailSafeReport.reset()
    }

    override class func tearDown() {
        DelightFailSafeReport.printSummaryIfReady()
        super.tearDown()
    }

    @MainActor
    func assertShowNothingNoThrow() {
        XCTAssertFalse(controller.isPresented)
        if case .hidden = controller.state {
            return
        }
        if case .idle = controller.state {
            return
        }
        if case .loading = controller.state {
            return
        }
        XCTFail("Expected hidden, idle, or loading (no popup), got \(controller.state)")
    }
}

// MARK: - Mock URL protocol

final class MockDelightURLProtocol: URLProtocol {
    static var responseHandler: ((URLRequest) -> (HTTPURLResponse, Data))?

    static func reset() {
        responseHandler = { _ in
            (
                HTTPURLResponse(
                    url: URL(string: "https://cdn.test/configs/default.json")!,
                    statusCode: 404,
                    httpVersion: nil,
                    headerFields: nil
                )!,
                Data()
            )
        }
    }

    static func makeSession() -> URLSession {
        reset()
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockDelightURLProtocol.self]
        return URLSession(configuration: config)
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.responseHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        let (response, data) = handler(request)
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

func failSafePopupStateIsLoading(_ state: DelightPopupState) -> Bool {
    if case .loading = state { return true }
    return false
}

@MainActor
func failSafeWaitUntil(
    timeout: TimeInterval = 2,
    pollIntervalNanoseconds: UInt64 = 20_000_000,
    condition: () -> Bool
) async {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        if condition() { return }
        try? await Task.sleep(nanoseconds: pollIntervalNanoseconds)
    }
    XCTFail("Timed out waiting for condition")
}

func failSafeMakeConfig(
    hostDisplayName: String? = nil,
    brandName: String? = nil,
    suppressionRules: DelightSuppressionRulesDTO? = nil,
    applyDefaultSuppressionRules: Bool = true,
    rewards: [DelightPopupRewardDTO]
) -> DelightConfigDTO {
    DelightConfigDTO(
        partnerId: "test-partner",
        partnerLogo: nil,
        hostDisplayName: hostDisplayName,
        apiUrl: "https://api.rewardsbag.com",
        language: "en",
        popup: DelightPopupSectionDTO(
            enabled: true,
            defaultLocale: "en",
            locales: nil,
            theme: nil,
            rewards: rewards,
            enablePresentIcon: nil
        ),
        suppressionRules: suppressionRules ?? (applyDefaultSuppressionRules ? failSafeMakeSuppressionRules() : nil),
        brandName: brandName
    )
}

func failSafeMakeSuppressionRules() -> DelightSuppressionRulesDTO {
    DelightSuppressionRulesDTO(
        maxImpressionsPerUserPerMonth: 15,
        maxRewardsPerUserPerDay: 2,
        dailyCooldownHours: 0,
        maxImpressionsPerRewardWithoutEngagement: 3,
        restPeriodAfterNoEngagementDays: 21,
        suppressionPeriodAfterClickDays: 45,
        retentionDays: 90
    )
}

func failSafeMakeReward(id: String, ticketType: String? = nil) -> DelightPopupRewardDTO {
    DelightPopupRewardDTO(
        id: id,
        show: true,
        ctaUrl: "https://example.com/claim",
        postPopupMobileImage: "https://cdn.example.com/reward-mobile.png",
        postPopupWebImage: nil,
        logo: nil,
        partnerTermsUrl: nil,
        privacyPolicyUrl: nil,
        poweredByUrl: nil,
        locales: [
            "en": DelightPopupRewardLocaleDTO(
                headline: "Test reward",
                description: nil,
                ctaHelperText: nil,
                emailDisclaimer: nil,
                terms: nil,
                cta: nil
            )
        ],
        ticketType: ticketType,
        ageRequirement: nil
    )
}

func failSafeMakePayload(orderId: String, ticketTypes: [String]?) -> DelightRequestPayload {
    DelightRequestPayload(
        orderId: orderId,
        email: nil,
        userToken: UUID().uuidString.lowercased(),
        firstName: nil,
        lastName: nil,
        ticketTypes: ticketTypes
    )
}
