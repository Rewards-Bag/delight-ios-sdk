import Combine
import Foundation

enum DelightPopupState {
    case idle
    case loading
    case ready(DelightDecisionResponse, DelightPopupTheme)
    case hidden
    case failed(String)
}

@MainActor
final class DelightPopupController: ObservableObject {
    static let shared = DelightPopupController()

    @Published var isPresented = false
    @Published var state: DelightPopupState = .idle
    @Published var payload: DelightRequestPayload?
    @Published var callbacks: DelightCallbacks = .init()
    @Published var configuration: DelightConfiguration?

    private init() {}

    func show(payload: DelightRequestPayload, callbacks: DelightCallbacks) {
        self.payload = payload
        self.callbacks = callbacks
        self.state = .loading
        isPresented = true
        Task {
            await fetchDecision()
        }
    }

    func show() {
        isPresented = true
        if case .ready = state {
            return
        }
        state = .idle
    }

    func dismiss() {
        isPresented = false
        callbacks.onDismiss?()
        state = .hidden
    }

    private func fetchDecision() async {
        guard let payload else {
            state = .failed("Missing payload")
            return
        }

        guard let config = configuration else {
            let fallback = DelightDecisionResponse(
                show: true,
                templateId: "modal_card_v1",
                content: DelightContentDTO(
                    title: "Thanks for your order",
                    subtitle: "\(payload.firstName) \(payload.lastName) (\(payload.email))",
                    imageUrl: nil,
                    primaryCta: "Redeem",
                    secondaryCta: "Not now",
                    legalUrl: nil,
                    rewardId: "demo-reward",
                    deeplink: nil
                ),
                theme: DelightThemeDTO(
                    primaryHex: "#2563EB",
                    onPrimaryHex: "#FFFFFF",
                    surfaceHex: "#FFFFFF",
                    radiusDp: 16,
                    elevationDp: 8,
                    fontScale: 1
                ),
                tracking: DelightTrackingDTO(impressionToken: "demo-impression")
            )
            state = .ready(fallback, DelightPopupTheme.fromDTO(fallback.theme))
            return
        }

        do {
            let decision = try await DelightDecisionService.fetchDecision(
                configuration: config,
                payload: payload
            )

            guard decision.show else {
                dismiss()
                return
            }

            guard DelightTemplateRegistry.supports(templateId: decision.templateId) else {
                state = .failed("Unsupported template: \(decision.templateId)")
                return
            }

            state = .ready(decision, DelightPopupTheme.fromDTO(decision.theme))
        } catch {
            state = .failed("Failed to load reward")
        }
    }
}
