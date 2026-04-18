import Cocoa
import ApplicationServices

/// Manages auto-paste by simulating Cmd+V via CGEvent.
/// Requires Accessibility permission.
final class PasteService {

    /// Attempt to auto-paste by simulating Cmd+V.
    /// - Returns: true if the paste events were sent successfully.
    func attemptPaste() -> Bool {
        guard checkAccessibility() else {
            PPLogger.paste.warning("Accessibility permission not granted; cannot auto-paste")
            return false
        }

        // Create a Cmd+V key down event
        guard let keyDownEvent = CGEvent(keyboardEventSource: nil, virtualKey: 0x09, keyDown: true) else {
            PPLogger.paste.error("Failed to create key down event")
            return false
        }
        keyDownEvent.flags = .maskCommand

        // Create a Cmd+V key up event
        guard let keyUpEvent = CGEvent(keyboardEventSource: nil, virtualKey: 0x09, keyDown: false) else {
            PPLogger.paste.error("Failed to create key up event")
            return false
        }
        keyUpEvent.flags = .maskCommand

        // Post events to the system
        keyDownEvent.post(tap: .cghidEventTap)
        keyUpEvent.post(tap: .cghidEventTap)

        PPLogger.paste.info("Auto-paste Cmd+V events sent")
        return true
    }

    /// Check if accessibility permission is granted.
    func checkAccessibility() -> Bool {
        let trusted = AXIsProcessTrusted()
        PPLogger.paste.info("Accessibility check: \(trusted)")
        return trusted
    }
}
