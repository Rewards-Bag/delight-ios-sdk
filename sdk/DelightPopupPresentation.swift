import SwiftUI

@MainActor
public struct DelightPopupView: View {
    @ObservedObject private var controller = DelightPopupController.shared

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
        Delight.showRewardPopup(
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
        popupRoot
            .modifier(DelightSheetTransparentPresentationBackgroundModifier())
    }

    @ViewBuilder
    private var popupRoot: some View {
        switch controller.state {
        case .loading:
            ProgressView("Loading reward...")
                .padding(24)
                .presentationDetents([.medium])
        case .ready(let config, let theme, _):
            DelightTemplateRegistry.view(
                for: config,
                theme: theme,
                onPrimary: { rewardId in
                    controller.markRewardClicked(rewardId)
                    controller.callbacks.onPrimaryClick?(rewardId)
                    Self.dismiss()
                },
                onDismiss: {
                    controller.markDismissedByCloseButton()
                    Self.dismiss()
                }
            )
            .onAppear {
                controller.markPopupBecameVisible()
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

private struct DelightSheetTransparentPresentationBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 16.4, *) {
            content.presentationBackground(.clear)
        } else {
            content
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
            .sheet(isPresented: $controller.isPresented, onDismiss: {
                controller.handleSheetDidDismiss()
            }) {
                DelightPopupView()
            }
    }
}
