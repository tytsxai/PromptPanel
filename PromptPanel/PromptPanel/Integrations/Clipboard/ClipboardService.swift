import Cocoa

protocol ClipboardWriting {
    @discardableResult
    func writeText(_ text: String) -> Bool
}

/// Manages clipboard read/write operations.
final class ClipboardService: ClipboardWriting {

    /// Write text content to the system clipboard.
    /// - Returns: true if successful, false otherwise.
    @discardableResult
    func writeText(_ text: String) -> Bool {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        let success = pasteboard.setString(text, forType: .string)
        if success {
            PPLogger.clipboard.info("Clipboard write succeeded (\(text.count) chars)")
        } else {
            PPLogger.clipboard.error("Clipboard write failed")
        }
        return success
    }

    /// Read text from the system clipboard.
    func readText() -> String? {
        return NSPasteboard.general.string(forType: .string)
    }
}
