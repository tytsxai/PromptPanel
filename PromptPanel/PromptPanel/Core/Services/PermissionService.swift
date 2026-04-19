import Foundation
import Cocoa

@MainActor
protocol AccessibilityPermissionProviding: AnyObject {
    var isAccessibilityGranted: Bool { get }
    func refresh()
}

/// Service responsible for detecting and guiding accessibility permission.
@MainActor
final class PermissionService: ObservableObject, AccessibilityPermissionProviding {

    @Published private(set) var isAccessibilityGranted: Bool = false

    init() {
        refresh()
    }

    /// Refresh the current accessibility permission status.
    func refresh() {
        isAccessibilityGranted = AXIsProcessTrusted()
        PPLogger.permission.info("Accessibility permission: \(self.isAccessibilityGranted)")
    }

    /// Prompt the user to grant accessibility permission.
    /// Opens System Settings to the appropriate pane.
    func requestPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue(): true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        isAccessibilityGranted = trusted
        PPLogger.permission.info("Accessibility permission requested, current status: \(trusted)")
    }

    /// Open System Settings > Privacy & Security > Accessibility.
    func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}
