import Foundation
import Cocoa

/// Orchestrates the entry execution flow:
/// 1. Write to clipboard
/// 2. Close/defocus panel
/// 3. Check permissions
/// 4. Attempt auto-paste
/// 5. Handle success/failure
@MainActor
final class ExecuteService {

    private let clipboardService: ClipboardService
    private let pasteService: PasteService
    private let entryRepository: EntryRepository
    private let logRepository: LogRepository
    private let permissionService: PermissionService
    private let frontApplicationProvider: () -> String?

    /// Callback to close/hide the panel before pasting.
    var onClosePanel: (() -> Void)?

    /// Callback to show a user notification.
    var onShowNotification: ((String, Bool) -> Void)?

    init(
        clipboardService: ClipboardService,
        pasteService: PasteService,
        entryRepository: EntryRepository,
        logRepository: LogRepository,
        permissionService: PermissionService,
        frontApplicationProvider: @escaping () -> String?
    ) {
        self.clipboardService = clipboardService
        self.pasteService = pasteService
        self.entryRepository = entryRepository
        self.logRepository = logRepository
        self.permissionService = permissionService
        self.frontApplicationProvider = frontApplicationProvider
    }

    /// Execute an entry: clipboard → close panel → auto-paste → fallback.
    func execute(entry: Entry, currentProjectId: String) {
        PPLogger.execute.info("Executing entry: \(entry.id)")

        // Get the frontmost app bundle ID BEFORE we do anything
        let frontAppBundleId = frontApplicationProvider()

        // Step 1: Write to clipboard
        let clipboardSuccess = clipboardService.writeText(entry.content)

        guard clipboardSuccess else {
            // Clipboard write failed — cannot proceed
            PPLogger.execute.error("Clipboard write failed for entry \(entry.id)")
            logExecution(
                entry: entry,
                projectId: currentProjectId,
                frontAppBundleId: frontAppBundleId,
                clipboardSuccess: false,
                pasteAttempted: false,
                pasteSuccess: false,
                result: .failed
            )
            onShowNotification?("复制失败，请重试", false)
            return
        }

        // Step 2: Close panel to return focus to original app
        onClosePanel?()

        // Give the system a moment to restore focus
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
            guard let self = self else { return }
            self.performPaste(
                entry: entry,
                projectId: currentProjectId,
                frontAppBundleId: frontAppBundleId
            )
        }
    }

    private func performPaste(entry: Entry, projectId: String, frontAppBundleId: String?) {
        // Step 3: Check accessibility permission
        permissionService.refresh()
        let hasPermission = permissionService.isAccessibilityGranted

        guard hasPermission else {
            // No permission — clipboard-only mode
            PPLogger.execute.info("No accessibility permission; clipboard-only mode")
            logExecution(
                entry: entry,
                projectId: projectId,
                frontAppBundleId: frontAppBundleId,
                clipboardSuccess: true,
                pasteAttempted: false,
                pasteSuccess: false,
                result: .clipboardOnly
            )
            recordUsage(entry: entry)
            onShowNotification?("已复制到剪贴板，可手动粘贴 (⌘V)", true)
            return
        }

        // Step 4: Attempt auto-paste
        let pasteSuccess = pasteService.attemptPaste()

        if pasteSuccess {
            PPLogger.execute.info("Auto-paste succeeded for entry \(entry.id)")
            logExecution(
                entry: entry,
                projectId: projectId,
                frontAppBundleId: frontAppBundleId,
                clipboardSuccess: true,
                pasteAttempted: true,
                pasteSuccess: true,
                result: .success
            )
            recordUsage(entry: entry)
            // No notification needed on success — user sees content appear
        } else {
            // Paste failed but clipboard is intact
            PPLogger.execute.warning("Auto-paste failed for entry \(entry.id); clipboard fallback")
            logExecution(
                entry: entry,
                projectId: projectId,
                frontAppBundleId: frontAppBundleId,
                clipboardSuccess: true,
                pasteAttempted: true,
                pasteSuccess: false,
                result: .clipboardOnly
            )
            recordUsage(entry: entry)
            onShowNotification?("已复制，可手动粘贴 (⌘V)", true)
        }
    }

    private func recordUsage(entry: Entry) {
        do {
            try entryRepository.recordExecution(id: entry.id)
            NotificationCenter.default.post(name: .entriesDidChange, object: nil)
        } catch {
            PPLogger.execute.error("Failed to record usage: \(error.localizedDescription)")
        }
    }

    private func logExecution(
        entry: Entry,
        projectId: String,
        frontAppBundleId: String?,
        clipboardSuccess: Bool,
        pasteAttempted: Bool,
        pasteSuccess: Bool,
        result: Constants.ExecutionResult
    ) {
        let log = ExecutionLog(
            entryId: entry.id,
            projectId: projectId,
            frontAppBundleId: frontAppBundleId,
            hasAccessibility: permissionService.isAccessibilityGranted,
            clipboardSuccess: clipboardSuccess,
            pasteAttempted: pasteAttempted,
            pasteSuccess: pasteSuccess,
            result: result.rawValue
        )
        do {
            try logRepository.record(log)
        } catch {
            PPLogger.execute.error("Failed to write execution log: \(error.localizedDescription)")
        }
    }
}
