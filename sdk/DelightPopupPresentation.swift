import SwiftUI

@MainActor
public struct DelightPopupView: View {
    @ObservedObject private var controller = DelightPopupController.shared
    @State private var hasTrackedImpression = false

    public init() {}

    public static func identify(orderId: String, email: String, firstName: String, lastName: String) {
        DelightPopupController.shared.payload = DelightRequestPayload(
            orderId: orderId,
            email: email,
            firstName: firstName,
            lastName: lastName
        )
    }

    public static func show(orderId: String, email: String, firstName: String, lastName: String) {
        Delight.showReward(
            DelightRequestPayload(
                orderId: orderId,
                email: email,
                firstName: firstName,
                lastName: lastName
            )
        )
    }

    public static func show() {
        DelightPopupController.shared.show()
    }

    public static func dismiss() {
        DelightPopupController.shared.dismiss()
    }

    public var body: some View {
        switch controller.state {
        case .loading:
            ProgressView("Loading reward...")
                .padding(24)
                .presentationDetents([.medium])
        case .ready(let config, let theme):
            DelightTemplateRegistry.view(
                for: config,
                theme: theme,
                onPrimary: { rewardId in
                    controller.callbacks.onPrimaryClick?(rewardId)
                    Self.dismiss()
                },
                onDismiss: {
                    Self.dismiss()
                }
            )
            .onAppear {
                if !hasTrackedImpression {
                    hasTrackedImpression = true
                    controller.callbacks.onImpression?(nil)
                }
            }
        case .failed(let message):
            VStack(spacing: 12) {
                Text("Unable to load reward")
                    .font(.headline)
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Button("Dismiss") {
                    Self.dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(24)
            .presentationDetents([.medium])
        case .idle, .hidden:
            EmptyView()
        }
    }
}

@MainActor
public struct DelightPopupPresenter: View {
    @ObservedObject private var controller = DelightPopupController.shared

    public init() {}

    public var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .sheet(isPresented: $controller.isPresented) {
                DelightPopupView()
            }
    }
}
