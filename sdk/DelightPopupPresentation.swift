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
#if DEBUG
            if DelightRuntimeTestFlags.suppressTemplateBody {
                Color.clear
                    .onAppear {
                        controller.tearDownAfterRenderFailure()
                    }
            } else {
                popupTemplate(config: config, theme: theme)
            }
#else
            popupTemplate(config: config, theme: theme)
#endif
        case .failed, .idle, .hidden:
            // A clear full-screen window would swallow taps on the host screen,
            // including ticket activation. Never keep that window once the offer is gone.
            Color.clear
                .frame(width: 0, height: 0)
                .allowsHitTesting(false)
                .onAppear {
                    Task { @MainActor in
#if canImport(UIKit)
                        DelightPopupOverlay.hide()
                        DelightMinimizedBadgeOverlay.hide()
                        DelightPageScopedPresentIcon.hide(intentional: true)
#endif
                    }
                }
        }
    }

    @ViewBuilder
    private func popupTemplate(config: DelightConfigDTO, theme: DelightPopupTheme) -> some View {
        DelightTemplateRegistry.view(
            for: config,
            theme: theme,
            closeButtonAction: controller.closeButtonAction(for: config),
            onMinimize: {
                guard controller.shouldMinimizeOnCloseTap(for: config) else { return }
                controller.minimize()
            },
            onPrimary: { rewardId in
                DelightFailSafe.run {
                    controller.markRewardClicked(rewardId)
                    DelightHostCallbacks.invokePrimaryClick(controller.callbacks.onPrimaryClick, rewardId: rewardId)
                    if !config.isGWRBrand {
                        controller.dismissSafely()
                    }
                } onFailure: { _ in
                    controller.tearDownAfterRenderFailure()
                }
            },
            onDismiss: {
                DelightFailSafe.run {
                    controller.markDismissedByCloseButton()
                    controller.dismissSafely()
                } onFailure: { _ in
                    controller.tearDownAfterRenderFailure()
                }
            },
            onRewardsExhausted: {
                DelightFailSafe.run {
                    controller.completeAllRewards()
                } onFailure: { _ in
                    controller.tearDownAfterRenderFailure()
                }
            },
            currentRewardIndex: $controller.carouselRewardIndex,
            claimedRewardIds: $controller.claimedRewardIds
        )
        .onAppear {
            DelightFailSafe.run {
                controller.markRewardBecameVisible(at: controller.carouselRewardIndex, in: config)
            } onFailure: { _ in
                controller.tearDownAfterRenderFailure()
            }
        }
        .onChange(of: controller.carouselRewardIndex) { index in
            DelightFailSafe.run {
                controller.markRewardBecameVisible(at: index, in: config)
            } onFailure: { _ in
                controller.tearDownAfterRenderFailure()
            }
        }
    }
}

@MainActor
public struct DelightPopupPresenter: View {
    public init() {}

    public var body: some View {
#if canImport(UIKit)
        DelightPagePresenceAnchor()
            .frame(width: 0, height: 0)
#else
        Color.clear
            .frame(width: 0, height: 0)
#endif
    }
}

#if canImport(UIKit)
private struct DelightPagePresenceAnchor: UIViewRepresentable {
    func makeUIView(context: Context) -> DelightPagePresenceView {
        let view = DelightPagePresenceView()
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ uiView: DelightPagePresenceView, context: Context) {}
}

private final class DelightPagePresenceView: UIView {
    private var wasInWindow = false

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil {
            wasInWindow = true
            return
        }
        guard wasInWindow else { return }
        wasInWindow = false
        Task { @MainActor in
            DelightPopupController.shared.retirePresentIconForPageLeave()
        }
    }
}
#endif

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

        let window = DelightHostSafeWindow(windowScene: windowScene)
        window.windowLevel = UIWindow.Level(rawValue: UIWindow.Level.normal.rawValue + 1)
        window.backgroundColor = UIColor.clear

        let host = UIHostingController(rootView: DelightPopupView())
        host.view.backgroundColor = UIColor.clear
        window.rootViewController = host
        window.isHidden = false
        popupWindow = window
    }

    static func hide() {
        if let window = popupWindow as? DelightHostSafeWindow {
            window.passesTouchesToHost = true
        }
        popupWindow?.isUserInteractionEnabled = false
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

/// GWR gift icon. It is added to the page that was showing when the customer minimised,
/// so a later screen does not keep it. Leaving that page removes it for the booking.
@MainActor
enum DelightPageScopedPresentIcon {
    private static var anchorController: DelightPageAnchorController?
    private static var badgeController: UIHostingController<DelightMinimizedRewardBadge>?
    private static var onPageLeft: (() -> Void)?
    private static var suppressLeave = false

    static func show(
        theme: DelightPopupTheme,
        onTap: @escaping () -> Void,
        onPageLeft: @escaping () -> Void
    ) {
        hide(intentional: true)
        guard let page = topViewController(), page.viewIfLoaded != nil else { return }
        self.onPageLeft = onPageLeft

        let anchor = DelightPageAnchorController()
        anchor.onDidDisappear = {
            guard !suppressLeave else { return }
            let callback = self.onPageLeft
            self.onPageLeft = nil
            hide(intentional: true)
            callback?()
        }
        page.addChild(anchor)
        anchor.view.isUserInteractionEnabled = false
        anchor.view.frame = .zero
        page.view.addSubview(anchor.view)
        anchor.didMove(toParent: page)
        anchor.beginWatching(page: page)
        anchorController = anchor

        let badge = UIHostingController(
            rootView: DelightMinimizedRewardBadge(theme: theme, onTap: onTap)
        )
        badge.view.backgroundColor = UIColor.clear
        badge.view.translatesAutoresizingMaskIntoConstraints = false
        page.view.addSubview(badge.view)
        let guide = page.view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            badge.view.widthAnchor.constraint(equalToConstant: 80),
            badge.view.heightAnchor.constraint(equalToConstant: 80),
            badge.view.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -16),
            badge.view.bottomAnchor.constraint(equalTo: guide.bottomAnchor, constant: -16)
        ])
        badgeController = badge
    }

    static func hide(intentional: Bool) {
        let previous = suppressLeave
        suppressLeave = true
        anchorController?.onDidDisappear = nil
        anchorController?.willMove(toParent: nil)
        anchorController?.view.removeFromSuperview()
        anchorController?.removeFromParent()
        anchorController = nil
        badgeController?.view.removeFromSuperview()
        badgeController = nil
        if intentional {
            onPageLeft = nil
        }
        suppressLeave = previous
    }

    private static func topViewController() -> UIViewController? {
        guard let scene = DelightOverlayWindowScene.active() else { return nil }
        let root = scene.windows.first(where: \.isKeyWindow)?.rootViewController
            ?? scene.windows.first?.rootViewController
        guard let root else { return nil }
        if let navigation = navigationController(from: root),
           let visible = navigation.visibleViewController {
            return deepest(visible)
        }
        return deepest(root)
    }

    /// SwiftUI NavigationStack keeps the window root mounted and pushes the
    /// booking screen as the navigation controller's visible page.
    private static func navigationController(from viewController: UIViewController) -> UINavigationController? {
        if let navigation = viewController as? UINavigationController {
            return navigation
        }
        if let navigation = viewController.navigationController {
            return navigation
        }
        for child in viewController.children where !(child is DelightPageAnchorController) {
            if let navigation = navigationController(from: child) {
                return navigation
            }
        }
        guard let view = viewController.viewIfLoaded else { return nil }
        return navigationController(in: view)
    }

    private static func navigationController(in view: UIView) -> UINavigationController? {
        if let bar = view as? UINavigationBar, let navigation = bar.delegate as? UINavigationController {
            return navigation
        }
        var responder: UIResponder? = view.next
        while let current = responder {
            if let navigation = current as? UINavigationController {
                return navigation
            }
            responder = current.next
        }
        for subview in view.subviews {
            if let navigation = navigationController(in: subview) {
                return navigation
            }
        }
        return nil
    }

    private static func deepest(_ viewController: UIViewController?) -> UIViewController? {
        guard let viewController, !(viewController is DelightPageAnchorController) else { return nil }
        if let presented = viewController.presentedViewController, !(presented is DelightPageAnchorController) {
            return deepest(presented)
        }
        if let navigation = viewController as? UINavigationController {
            let visible = navigation.visibleViewController ?? navigation.topViewController
            if let visible, visible !== navigation {
                return deepest(visible)
            }
        }
        if let tabs = viewController as? UITabBarController, let selected = tabs.selectedViewController {
            return deepest(selected)
        }
        if let page = viewController as? UIPageViewController, let current = page.viewControllers?.first {
            return deepest(current)
        }
        for child in viewController.children.reversed() where !(child is DelightPageAnchorController) {
            if child is UINavigationController || child is UITabBarController || child is UIPageViewController {
                return deepest(child)
            }
        }
        return viewController
    }
}

private final class DelightPageAnchorController: UIViewController {
    var onDidDisappear: (() -> Void)?
    private var navigationObservation: NSKeyValueObservation?
    private weak var anchoredPage: UIViewController?
    private var didReportLeave = false

    func beginWatching(page: UIViewController) {
        anchoredPage = page
        guard let navigation = page.navigationController else { return }
        navigationObservation = navigation.observe(\.viewControllers, options: [.new]) { [weak self] navigation, _ in
            DispatchQueue.main.async {
                self?.leaveIfPageCovered(navigation)
            }
        }
    }

    private func leaveIfPageCovered(_ navigation: UINavigationController) {
        guard let page = anchoredPage else { return }
        guard navigation.visibleViewController !== page else { return }
        reportLeave()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        reportLeave()
    }

    private func reportLeave() {
        guard !didReportLeave else { return }
        didReportLeave = true
        navigationObservation?.invalidate()
        navigationObservation = nil
        onDidDisappear?()
    }
}

/// Full-screen overlay that can be told to stop taking taps so the host app,
/// including ticket activation, stays usable if the popup is dismissed or fails.
private final class DelightHostSafeWindow: UIWindow {
    var passesTouchesToHost = false

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if passesTouchesToHost || !isUserInteractionEnabled || isHidden {
            return nil
        }
        return super.hitTest(point, with: event)
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
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel("Open reward offer")
    }
}

private struct DelightMinimizedBadgePulseRing: View {
    let color: Color
    let delay: Double

    @State private var isPulsing = false
    @State private var pulseTask: Task<Void, Never>?

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
                pulseTask?.cancel()
                pulseTask = Task { @MainActor in
                    let delayNs = UInt64(max(delay, 0) * 1_000_000_000)
                    try? await Task.sleep(nanoseconds: delayNs)
                    guard !Task.isCancelled else { return }
                    withAnimation(.easeOut(duration: 1.8).repeatForever(autoreverses: false)) {
                        isPulsing = true
                    }
                }
            }
            .onDisappear {
                pulseTask?.cancel()
                pulseTask = nil
                isPulsing = false
            }
    }
}
