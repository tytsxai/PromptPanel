import Foundation
import KeyboardShortcuts

// MARK: - Hotkey Name Registration

extension KeyboardShortcuts.Name {
    /// The global hotkey to toggle the quick panel.
    static let togglePanel = Self("togglePanel", default: .init(.space, modifiers: [.option]))
}

/// Manages global hotkey registration and handling.
@MainActor
final class HotkeyService {

    private let onTogglePanel: () -> Void

    init(onTogglePanel: @escaping () -> Void) {
        self.onTogglePanel = onTogglePanel
    }

    /// Start listening for the global hotkey.
    func start() {
        KeyboardShortcuts.onKeyUp(for: .togglePanel) { [weak self] in
            PPLogger.hotkey.info("Toggle panel hotkey triggered")
            self?.onTogglePanel()
        }
        PPLogger.hotkey.info("Hotkey service started")
    }

    /// Stop listening.
    func stop() {
        KeyboardShortcuts.disable(.togglePanel)
        PPLogger.hotkey.info("Hotkey service stopped")
    }
}
