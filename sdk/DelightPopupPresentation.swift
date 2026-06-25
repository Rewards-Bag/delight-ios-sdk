import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

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
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea()
    }

    @ViewBuilder
    private var popupRoot: some View {
        switch controller.state {
        case .loading:
            ZStack {
                Color.black.opacity(0.4)
                ProgressView("Loading reward...")
                    .padding(24)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        case .ready(let config, let theme, _):
            DelightTemplateRegistry.view(
                for: config,
                theme: theme,
                closeButtonAction: controller.closeButtonAction(for: config),
                onMinimize: {
                    guard controller.shouldMinimizeOnCloseTap(for: config) else { return }
                    controller.minimize()
                },
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
        case .failed:
            EmptyView()
        case .idle, .hidden:
            EmptyView()
        }
    }
}

@MainActor
public struct DelightPopupPresenter: View {
    public init() {}

    public var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
    }
}

#if canImport(UIKit)
@MainActor
enum DelightOverlayWindowScene {
    static func active() -> UIWindowScene? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        for scene in scenes {
            let state = scene.activationState
            if state == .foregroundActive || state == .foregroundInactive {
                return scene
            }
        }
        return scenes.first
    }

    static func keyWindowSafeAreaBottom(in scene: UIWindowScene) -> CGFloat {
        scene.windows.first(where: \.isKeyWindow)?.safeAreaInsets.bottom ?? 0
    }
}

@MainActor
enum DelightPopupOverlay {
    private static var popupWindow: UIWindow?

    static func show() {
        guard popupWindow == nil else { return }
        guard let windowScene = DelightOverlayWindowScene.active() else { return }

        let window = UIWindow(windowScene: windowScene)
        window.windowLevel = UIWindow.Level(rawValue: UIWindow.Level.normal.rawValue + 1)
        window.backgroundColor = UIColor.clear

        let host = UIHostingController(rootView: DelightPopupView())
        host.view.backgroundColor = UIColor.clear
        window.rootViewController = host
        window.isHidden = false
        popupWindow = window
    }

    static func hide() {
        popupWindow?.isHidden = true
        popupWindow?.rootViewController = nil
        popupWindow = nil
    }
}

@MainActor
enum DelightMinimizedBadgeOverlay {
    private static var badgeWindow: DelightPassthroughWindow?
    private static let containerSize: CGFloat = 80
    private static let trailingPadding: CGFloat = 16
    private static let extraBottomPadding: CGFloat = 16

    static func show(theme: DelightPopupTheme, onTap: @escaping () -> Void) {
        hide()

        guard let windowScene = DelightOverlayWindowScene.active() else {
            return
        }

        let bottomPadding = DelightOverlayWindowScene.keyWindowSafeAreaBottom(in: windowScene) + extraBottomPadding
        let screenBounds = windowScene.screen.bounds
        let badgeFrame = CGRect(
            x: screenBounds.maxX - trailingPadding - containerSize,
            y: screenBounds.maxY - bottomPadding - containerSize,
            width: containerSize,
            height: containerSize
        )

        let window = DelightPassthroughWindow(windowScene: windowScene)
        window.interactiveRect = badgeFrame
        window.windowLevel = UIWindow.Level(rawValue: UIWindow.Level.normal.rawValue + 1)
        window.backgroundColor = UIColor.clear

        let host = UIHostingController(
            rootView: DelightMinimizedRewardBadge(theme: theme, onTap: onTap)
                .frame(width: containerSize, height: containerSize)
        )
        host.view.backgroundColor = UIColor.clear
        host.view.frame = badgeFrame
        window.setHostedContent(host, frame: badgeFrame)
        window.isHidden = false
        badgeWindow = window
    }

    static func hide() {
        badgeWindow?.clearHostedContent()
        badgeWindow?.isHidden = true
        badgeWindow = nil
    }
}

private final class DelightPassthroughWindow: UIWindow {
    var interactiveRect: CGRect = .zero
    private var hostController: UIViewController?

    func setHostedContent(_ controller: UIViewController, frame: CGRect) {
        clearHostedContent()
        hostController = controller
        controller.view.frame = frame
        addSubview(controller.view)
    }

    func clearHostedContent() {
        hostController?.view.removeFromSuperview()
        hostController = nil
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard interactiveRect.contains(point) else { return nil }
        return super.hitTest(point, with: event)
    }
}
#endif

private enum DelightMinimizedBadgeMetrics {
    static let badgeDiameter: CGFloat = 56
    static let notificationDotSize: CGFloat = 11
}

private struct DelightMinimizedRewardBadge: View {
    let theme: DelightPopupTheme
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack {
                DelightMinimizedBadgePulseRing(color: theme.primary, delay: 0)
                DelightMinimizedBadgePulseRing(color: theme.primary, delay: 0.9)

                Circle()
                    .fill(theme.primary)
                    .frame(
                        width: DelightMinimizedBadgeMetrics.badgeDiameter,
                        height: DelightMinimizedBadgeMetrics.badgeDiameter
                    )

                Image(systemName: "gift.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(theme.onPrimary)

                Circle()
                    .fill(Color(red: 0.92, green: 0.18, blue: 0.18))
                    .frame(
                        width: DelightMinimizedBadgeMetrics.notificationDotSize,
                        height: DelightMinimizedBadgeMetrics.notificationDotSize
                    )
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: 2)
                    )
                    .offset(
                        x: DelightMinimizedBadgeMetrics.badgeDiameter / 2
                            - DelightMinimizedBadgeMetrics.notificationDotSize / 2 - 2,
                        y: -(DelightMinimizedBadgeMetrics.badgeDiameter / 2
                            - DelightMinimizedBadgeMetrics.notificationDotSize / 2 - 2)
                    )
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open reward offer")
    }
}

private struct DelightMinimizedBadgePulseRing: View {
    let color: Color
    let delay: Double

    @State private var isPulsing = false

    var body: some View {
        Circle()
            .fill(color.opacity(0.35))
            .frame(
                width: DelightMinimizedBadgeMetrics.badgeDiameter,
                height: DelightMinimizedBadgeMetrics.badgeDiameter
            )
            .scaleEffect(isPulsing ? 1.42 : 1)
            .opacity(isPulsing ? 0 : 0.55)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    withAnimation(.easeOut(duration: 1.8).repeatForever(autoreverses: false)) {
                        isPulsing = true
                    }
                }
            }
    }
}
