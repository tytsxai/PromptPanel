import Foundation
import KeyboardShortcuts

private let preferredTogglePanelShortcut = KeyboardShortcuts.Shortcut(.p, modifiers: [.option, .shift])

// MARK: - Hotkey Name Registration

extension KeyboardShortcuts.Name {
    /// The global hotkey to toggle the quick panel.
    static let togglePanel = Self("togglePanel", default: preferredTogglePanelShortcut)
}

protocol HotkeyRegistrationHandling {
    func onKeyUp(for name: KeyboardShortcuts.Name, action: @escaping () -> Void)
    func disable(_ name: KeyboardShortcuts.Name)
}

struct KeyboardShortcutsRegistrar: HotkeyRegistrationHandling {
    func onKeyUp(for name: KeyboardShortcuts.Name, action: @escaping () -> Void) {
        KeyboardShortcuts.onKeyUp(for: name, action: action)
    }

    func disable(_ name: KeyboardShortcuts.Name) {
        KeyboardShortcuts.disable(name)
    }
}

/// Manages global hotkey registration and handling.
@MainActor
final class HotkeyService {
    private let onTogglePanel: () -> Void
    private let registrar: HotkeyRegistrationHandling
    private let panelOpenTracker: PanelOpenTracker?

    init(
        onTogglePanel: @escaping () -> Void,
        registrar: HotkeyRegistrationHandling = KeyboardShortcutsRegistrar(),
        panelOpenTracker: PanelOpenTracker? = nil
    ) {
        self.onTogglePanel = onTogglePanel
        self.registrar = registrar
        self.panelOpenTracker = panelOpenTracker
    }

    /// Start listening for the global hotkey.
    func start() {
        registrar.onKeyUp(for: .togglePanel) { [weak self] in
            self?.handleTogglePanel()
        }
        PPLogger.hotkey.info("Hotkey service started")
    }

    /// Stop listening.
    func stop() {
        registrar.disable(.togglePanel)
        PPLogger.hotkey.info("Hotkey service stopped")
    }

    private func handleTogglePanel() {
        panelOpenTracker?.markHotkeyTriggered()
        PPLogger.hotkey.info("Toggle panel hotkey triggered")
        onTogglePanel()
    }
}
