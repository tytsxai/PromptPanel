import Cocoa

/// Manages the quick panel (NSPanel) lifecycle:
/// show, hide, toggle, focus control, Esc/click-outside behavior.
@MainActor
final class PanelService {

    private var panel: NSPanel?
    private var panelDelegate: PanelDelegate?
    private var targetApplication: NSRunningApplication?
    private let appState: AppState

    /// Callback to create the panel content view.
    var contentViewProvider: (() -> NSView)?
    var onWillShow: (() -> Void)?

    init(appState: AppState) {
        self.appState = appState
    }

    /// Toggle panel visibility.
    func toggle() {
        if appState.isPanelVisible {
            hide()
        } else {
            show()
        }
    }

    /// Show the panel.
    func show() {
        if panel == nil {
            createPanel()
        }

        guard let panel = panel else { return }

        if let frontmostApplication = NSWorkspace.shared.frontmostApplication,
           frontmostApplication.bundleIdentifier != Bundle.main.bundleIdentifier {
            targetApplication = frontmostApplication
        }

        onWillShow?()

        // Position panel in center of the active screen
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let panelSize = panel.frame.size
            let x = screenFrame.midX - panelSize.width / 2
            let y = screenFrame.midY - panelSize.height / 2 + screenFrame.height * 0.1
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }

        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        panel.orderFrontRegardless()

        appState.isPanelVisible = true
        PPLogger.panel.info("Panel shown")
    }

    /// Hide the panel.
    func hide() {
        guard appState.isPanelVisible else {
            panel?.orderOut(nil)
            return
        }

        panel?.orderOut(nil)
        appState.isPanelVisible = false
        reactivateTargetApplication()
        PPLogger.panel.info("Panel hidden")
    }

    func targetApplicationBundleId() -> String? {
        targetApplication?.bundleIdentifier
    }

    /// Create the NSPanel with proper configuration.
    private func createPanel() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 680, height: 460),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.level = .floating
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.animationBehavior = .utilityWindow
        panel.collectionBehavior = [.transient, .ignoresCycle]
        panel.isReleasedWhenClosed = false
        panel.backgroundColor = .clear
        panel.isOpaque = false

        // Set content view
        if let contentView = contentViewProvider?() {
            panel.contentView = contentView
        }

        // Handle Esc key and click-outside
        let delegate = PanelDelegate(onClose: { [weak self] in
            self?.hide()
        })
        panel.delegate = delegate

        self.panel = panel
        self.panelDelegate = delegate
        PPLogger.panel.info("Panel created")
    }

    private func reactivateTargetApplication() {
        guard let targetApplication else {
            return
        }
        _ = targetApplication.activate(options: [])
        self.targetApplication = nil
    }
}

// MARK: - Panel Delegate

private class PanelDelegate: NSObject, NSWindowDelegate {

    let onClose: () -> Void

    init(onClose: @escaping () -> Void) {
        self.onClose = onClose
    }

    func windowDidResignKey(_ notification: Notification) {
        // Click outside panel → close
        onClose()
    }

    func windowWillClose(_ notification: Notification) {
        onClose()
    }
}
