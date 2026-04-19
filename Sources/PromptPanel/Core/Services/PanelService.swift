import Cocoa

/// Manages the quick panel (NSPanel) lifecycle:
/// show, hide, toggle, focus control, Esc/click-outside behavior.
@MainActor
final class PanelService {
    enum ActivationAction: Equatable {
        case stable
        case retry(nextAttempt: Int)
        case failed
    }

    private var panel: NSPanel?
    private var panelDelegate: PanelDelegate?
    private var targetApplication: NSRunningApplication?
    private var deactivateCloseGraceDeadline: Date?
    private let appState: AppState
    private let panelVisibilityCoordinator = PanelVisibilityCoordinator()
    private let panelOpenTracker: PanelOpenTracker?

    /// Callback to create the panel content view.
    var contentViewProvider: (() -> NSView)?
    var onWillShow: (() -> Void)?
    var onDidStabilizeActivation: (() -> Void)?
    var onPanelContentSizeChanged: ((NSSize) -> Void)?

    init(appState: AppState, panelOpenTracker: PanelOpenTracker? = nil) {
        self.appState = appState
        self.panelOpenTracker = panelOpenTracker
    }

    /// Toggle panel visibility.
    func toggle() {
        switch panelVisibilityCoordinator.toggleAction() {
        case .show:
            show()
        case .hide:
            hide()
        }
    }

    /// Show the panel.
    func show() {
        guard panelVisibilityCoordinator.beginShow() else {
            PPLogger.panel.debug("Panel show ignored because state is already \(String(describing: self.panelVisibilityCoordinator.state))")
            return
        }

        if panel == nil {
            createPanel()
        }

        guard let panel = panel else {
            panelVisibilityCoordinator.finishHide()
            return
        }

        if let frontmostApplication = NSWorkspace.shared.frontmostApplication,
           frontmostApplication.bundleIdentifier != Bundle.main.bundleIdentifier {
            targetApplication = frontmostApplication
        }

        onWillShow?()
        deactivateCloseGraceDeadline = Date().addingTimeInterval(
            TimeInterval(Constants.panelDeactivateCloseGraceMs) / 1000
        )

        // Position panel in center of the active screen
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let panelSize = panel.frame.size
            let x = screenFrame.midX - panelSize.width / 2
            let y = screenFrame.midY - panelSize.height / 2 + screenFrame.height * 0.1
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }

        appState.isPanelVisible = true
        panelVisibilityCoordinator.finishShow()
        panelOpenTracker?.markPanelShown()
        applyActivationPolicyForCurrentVisibility()
        activatePromptPanelApplication()
        bringPanelToFront(panel)
        stabilizePanelActivation(panel)
        PPLogger.panel.info("Panel shown")
    }

    /// Hide the panel.
    func hide() {
        guard panelVisibilityCoordinator.beginHide() else {
            return
        }

        panel?.orderOut(nil)
        appState.isPanelVisible = false
        deactivateCloseGraceDeadline = nil
        panelVisibilityCoordinator.finishHide()
        if panelOpenTracker?.currentTrace?.searchFieldFocusedAt == nil {
            panelOpenTracker?.cancelCurrentTrace(reason: "panel_hidden_before_focus")
        }
        reactivateTargetApplication()
        applyActivationPolicyForCurrentVisibility()
        PPLogger.panel.info("Panel hidden")
    }

    func targetApplicationBundleId() -> String? {
        targetApplication?.bundleIdentifier
    }

    func setPinned(_ isPinned: Bool) {
        appState.isPanelPinned = isPinned

        guard let panel else {
            return
        }

        applyPinnedWindowBehavior(to: panel)
        if isPinned, panel.isVisible {
            bringPanelToFront(panel)
        }
    }

    /// Create the NSPanel with proper configuration.
    private func createPanel() {
        let windowSize = Constants.panelWindowContentSize(for: appState.panelContentSize)
        let panel = QuickPanelWindow(
            contentRect: NSRect(origin: .zero, size: windowSize),
            styleMask: [.resizable],
            backing: .buffered,
            defer: false
        )

        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.becomesKeyOnlyIfNeeded = false
        panel.animationBehavior = .utilityWindow
        panel.isReleasedWhenClosed = false
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.contentMinSize = Constants.panelWindowContentSize(for: Constants.panelMinContentSize)
        panel.contentMaxSize = Constants.panelWindowContentSize(for: Constants.panelMaxContentSize)
        applyPinnedWindowBehavior(to: panel)

        configureWindowButtons(for: panel)

        // Set content view
        if let contentView = contentViewProvider?() {
            panel.contentView = makePanelBackgroundView(contentView: contentView)
        }

        // Handle Esc key and click-outside
        let delegate = PanelDelegate(
            onClose: { [weak self] in
                self?.hide()
            },
            onResize: { [weak self] contentSize in
                self?.handlePanelResize(contentSize: contentSize)
            },
            shouldDeferCloseOnDeactivate: { [weak self] in
                self?.shouldDeferCloseOnDeactivate() ?? false
            },
            shouldCloseOnDeactivate: { [weak self] in
                self?.appState.isPanelPinned == false
            }
        )
        panel.delegate = delegate

        self.panel = panel
        self.panelDelegate = delegate
        PPLogger.panel.info("Panel created")
    }

    private func configureWindowButtons(for panel: NSPanel) {
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        panel.standardWindowButton(.closeButton)?.isHidden = true
    }

    private func makePanelBackgroundView(contentView: NSView) -> NSVisualEffectView {
        let backgroundView = NSVisualEffectView()
        backgroundView.material = .underWindowBackground
        backgroundView.blendingMode = .behindWindow
        backgroundView.state = .followsWindowActiveState
        backgroundView.wantsLayer = true
        backgroundView.layer?.cornerRadius = 14
        backgroundView.layer?.masksToBounds = true

        contentView.translatesAutoresizingMaskIntoConstraints = false
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = NSColor.clear.cgColor
        backgroundView.addSubview(contentView)

        NSLayoutConstraint.activate([
            contentView.leadingAnchor.constraint(equalTo: backgroundView.leadingAnchor, constant: Constants.panelContentInsets.left),
            contentView.trailingAnchor.constraint(equalTo: backgroundView.trailingAnchor, constant: -Constants.panelContentInsets.right),
            contentView.topAnchor.constraint(equalTo: backgroundView.topAnchor, constant: Constants.panelContentInsets.top),
            contentView.bottomAnchor.constraint(equalTo: backgroundView.bottomAnchor, constant: -Constants.panelContentInsets.bottom)
        ])

        return backgroundView
    }

    private func handlePanelResize(contentSize: NSSize) {
        let panelContentSize = NSSize(
            width: max(Constants.panelMinContentSize.width, contentSize.width - Constants.panelContentInsets.left - Constants.panelContentInsets.right),
            height: max(Constants.panelMinContentSize.height, contentSize.height - Constants.panelContentInsets.top - Constants.panelContentInsets.bottom)
        )
        let normalizedSize = NSSize(
            width: min(panelContentSize.width, Constants.panelMaxContentSize.width),
            height: min(panelContentSize.height, Constants.panelMaxContentSize.height)
        )
        guard appState.panelContentSize != normalizedSize else {
            return
        }
        appState.panelContentSize = normalizedSize
        onPanelContentSizeChanged?(normalizedSize)
    }

    private func applyPinnedWindowBehavior(to panel: NSPanel) {
        if appState.isPanelPinned {
            panel.level = .statusBar
            panel.isFloatingPanel = true
            panel.hidesOnDeactivate = false
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        } else {
            panel.level = .floating
            panel.isFloatingPanel = true
            panel.hidesOnDeactivate = false
            panel.collectionBehavior = [.transient, .ignoresCycle, .moveToActiveSpace, .fullScreenAuxiliary]
        }
    }

    private func reactivateTargetApplication() {
        guard let targetApplication else {
            return
        }
        let currentFrontmostBundleId = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        if currentFrontmostBundleId == Bundle.main.bundleIdentifier {
            _ = targetApplication.activate(options: [])
        } else {
            PPLogger.panel.info(
                "Skipped target app reactivation because frontmost app already changed to \(currentFrontmostBundleId ?? "unknown")"
            )
        }
        self.targetApplication = nil
    }

    private func stabilizePanelActivation(_ panel: NSPanel, attempt: Int = 0) {
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(attempt == 0 ? 0 : Constants.panelActivationRetryDelayMs)) { [weak self, weak panel] in
            guard let self, let panel else {
                return
            }
            guard self.panel === panel, self.appState.isPanelVisible else {
                return
            }

            let snapshot = PanelActivationSnapshot(
                appIsActive: NSApp.isActive,
                panelIsVisible: panel.isVisible,
                panelIsKey: panel.isKeyWindow
            )
            let action = Self.activationAction(
                snapshot: snapshot,
                attempt: attempt,
                maxAttempts: Constants.panelActivationMaxAttempts
            )

            switch action {
            case .stable:
                self.deactivateCloseGraceDeadline = nil
                self.panelOpenTracker?.recordPanelActivationCheck(attempt: attempt, snapshot: snapshot, final: true)
                self.onDidStabilizeActivation?()
            case .retry(let nextAttempt):
                self.panelOpenTracker?.recordPanelActivationCheck(attempt: attempt, snapshot: snapshot, final: false)
                self.activatePromptPanelApplication()
                self.bringPanelToFront(panel)
                self.stabilizePanelActivation(panel, attempt: nextAttempt)
            case .failed:
                self.deactivateCloseGraceDeadline = nil
                self.panelOpenTracker?.recordPanelActivationCheck(attempt: attempt, snapshot: snapshot, final: true)
                PPLogger.panel.error(
                    "panel_activation_failed attempt=\(attempt) app_active=\(snapshot.appIsActive) panel_visible=\(snapshot.panelIsVisible) panel_key=\(snapshot.panelIsKey)"
                )
            }
        }
    }

    private func activatePromptPanelApplication() {
        NSApp.activate(ignoringOtherApps: true)
        _ = NSRunningApplication.current.activate(options: [])
    }

    private func bringPanelToFront(_ panel: NSPanel) {
        panel.makeKeyAndOrderFront(nil)
        panel.makeMain()
        panel.orderFrontRegardless()
    }

    static func activationAction(
        snapshot: PanelActivationSnapshot,
        attempt: Int,
        maxAttempts: Int
    ) -> ActivationAction {
        if snapshot.isStable {
            return .stable
        }
        if attempt < maxAttempts {
            return .retry(nextAttempt: attempt + 1)
        }
        return .failed
    }

    static func desiredActivationPolicy(
        isPanelVisible: Bool,
        isMainWindowVisible: Bool
    ) -> NSApplication.ActivationPolicy {
        (isPanelVisible || isMainWindowVisible) ? .regular : .accessory
    }

    private func applyActivationPolicyForCurrentVisibility() {
        applyActivationPolicy(
            Self.desiredActivationPolicy(
                isPanelVisible: appState.isPanelVisible,
                isMainWindowVisible: appState.isMainWindowVisible
            )
        )
    }

    private func applyActivationPolicy(_ policy: NSApplication.ActivationPolicy) {
        guard NSApp.activationPolicy() != policy else {
            return
        }

        guard NSApp.setActivationPolicy(policy) else {
            PPLogger.app.error("Failed to switch activation policy to \(String(describing: policy))")
            return
        }

        PPLogger.app.info("Switched activation policy to \(String(describing: policy))")
    }

    private func shouldDeferCloseOnDeactivate(now: Date = Date()) -> Bool {
        guard let deactivateCloseGraceDeadline else {
            return false
        }
        return now < deactivateCloseGraceDeadline
    }
}

// MARK: - Panel Delegate

private class PanelDelegate: NSObject, NSWindowDelegate {

    let onClose: () -> Void
    let onResize: (NSSize) -> Void
    let shouldDeferCloseOnDeactivate: () -> Bool
    let shouldCloseOnDeactivate: () -> Bool
    private let resignCloseDelayMs = 80

    init(
        onClose: @escaping () -> Void,
        onResize: @escaping (NSSize) -> Void,
        shouldDeferCloseOnDeactivate: @escaping () -> Bool,
        shouldCloseOnDeactivate: @escaping () -> Bool
    ) {
        self.onClose = onClose
        self.onResize = onResize
        self.shouldDeferCloseOnDeactivate = shouldDeferCloseOnDeactivate
        self.shouldCloseOnDeactivate = shouldCloseOnDeactivate
    }

    func windowDidResize(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else {
            return
        }
        let contentRect = window.contentRect(forFrameRect: window.frame)
        onResize(contentRect.size)
    }

    func windowDidResignKey(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else {
            return
        }
        scheduleDeactivateCloseCheck(for: window)
    }

    private func scheduleDeactivateCloseCheck(for window: NSWindow) {
        // Delay the close check so transient focus churn during presentation does not
        // immediately dismiss the panel, while real click-outside transitions still do.
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(resignCloseDelayMs)) { [weak self, weak window] in
            guard let self, let window else {
                return
            }
            guard window.isVisible else {
                return
            }
            guard window.isKeyWindow == false else {
                return
            }
            guard NSApp.isActive == false else {
                return
            }
            guard self.shouldCloseOnDeactivate() else {
                return
            }
            if self.shouldDeferCloseOnDeactivate() {
                self.scheduleDeactivateCloseCheck(for: window)
                return
            }
            self.onClose()
        }
    }

    func windowWillClose(_ notification: Notification) {
        onClose()
    }
}

final class QuickPanelWindow: NSPanel {
    override var canBecomeKey: Bool {
        true
    }

    override var canBecomeMain: Bool {
        true
    }
}
