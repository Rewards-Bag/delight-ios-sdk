import Combine
import Foundation

enum DelightPopupState {
    case idle
    case loading
    case ready(DelightConfigDTO, DelightPopupTheme)
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
    @Published var config: DelightConfigDTO?

    private init() {}

    func show(payload: DelightRequestPayload, callbacks: DelightCallbacks) {
        self.payload = payload
        self.callbacks = callbacks
        self.state = .loading
        isPresented = true
        Task { await fetchConfigAndBuildPopup() }
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

    private func fetchConfigAndBuildPopup() async {
        guard payload != nil else {
            state = .failed("Missing payload")
            return
        }

        let resolvedConfig: DelightConfigDTO
        if let config {
            resolvedConfig = config
        } else {
            do {
                let bundledConfig = try DelightConfigService.loadBundledConfig()
                self.config = bundledConfig
                resolvedConfig = bundledConfig
            } catch {
                state = .failed("SDK not initialized and bundled config is unavailable.")
                return
            }
        }

        guard let popup = resolvedConfig.popup, popup.enabled == true else {
            state = .failed("Popup config missing or disabled")
            return
        }

        guard DelightTemplateRegistry.supports(templateId: resolvedConfig.templateId) else {
            state = .failed("Unsupported template: \(resolvedConfig.templateId)")
            return
        }

        let theme = DelightPopupTheme.fromBrandTheme(resolvedConfig.popup?.theme)
        state = .ready(resolvedConfig, theme)
    }
}
