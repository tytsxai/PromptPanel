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
    private let targetApplicationProvider: () -> String?
    private let currentFrontApplicationProvider: () -> String?

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
        targetApplicationProvider: @escaping () -> String?,
        currentFrontApplicationProvider: @escaping () -> String?
    ) {
        self.clipboardService = clipboardService
        self.pasteService = pasteService
        self.entryRepository = entryRepository
        self.logRepository = logRepository
        self.permissionService = permissionService
        self.targetApplicationProvider = targetApplicationProvider
        self.currentFrontApplicationProvider = currentFrontApplicationProvider
    }

    /// Execute an entry: clipboard → close panel → auto-paste → fallback.
    func execute(entry: Entry, currentProjectId: String) {
        PPLogger.execute.info("Executing entry: \(entry.id)")
        let startTime = DispatchTime.now().uptimeNanoseconds

        // Get the frontmost app bundle ID BEFORE we do anything
        let frontAppBundleId = targetApplicationProvider()

        // Step 1: Write to clipboard
        let clipboardSuccess = clipboardService.writeText(entry.content)

        guard clipboardSuccess else {
            // Clipboard write failed — cannot proceed
            PPLogger.execute.error("Clipboard write failed for entry \(entry.id)")
            logExecution(
                entry: entry,
                projectId: currentProjectId,
                frontAppBundleId: frontAppBundleId,
                observedAppBundleId: currentFrontApplicationProvider(),
                clipboardSuccess: false,
                pasteAttempted: false,
                pasteSuccess: false,
                result: .failed,
                failureReason: .clipboardWriteFailed,
                totalDurationMs: elapsedMilliseconds(since: startTime)
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
                frontAppBundleId: frontAppBundleId,
                startTime: startTime
            )
        }
    }

    private func performPaste(
        entry: Entry,
        projectId: String,
        frontAppBundleId: String?,
        startTime: UInt64
    ) {
        // Step 3: Check accessibility permission
        permissionService.refresh()
        let hasPermission = permissionService.isAccessibilityGranted
        let observedAppBundleId = currentFrontApplicationProvider()

        guard hasPermission else {
            // No permission — clipboard-only mode
            PPLogger.execute.info("No accessibility permission; clipboard-only mode")
            logExecution(
                entry: entry,
                projectId: projectId,
                frontAppBundleId: frontAppBundleId,
                observedAppBundleId: observedAppBundleId,
                clipboardSuccess: true,
                pasteAttempted: false,
                pasteSuccess: false,
                result: .clipboardOnly,
                failureReason: .accessibilityNotGranted,
                totalDurationMs: elapsedMilliseconds(since: startTime)
            )
            recordUsage(entry: entry)
            onShowNotification?("已复制到剪贴板，可手动粘贴 (⌘V)", true)
            return
        }

        if let frontAppBundleId, let observedAppBundleId, frontAppBundleId != observedAppBundleId {
            PPLogger.execute.warning("Target app not restored before paste: expected=\(frontAppBundleId), observed=\(observedAppBundleId)")
            logExecution(
                entry: entry,
                projectId: projectId,
                frontAppBundleId: frontAppBundleId,
                observedAppBundleId: observedAppBundleId,
                clipboardSuccess: true,
                pasteAttempted: false,
                pasteSuccess: false,
                result: .clipboardOnly,
                failureReason: .targetAppNotRestored,
                totalDurationMs: elapsedMilliseconds(since: startTime)
            )
            recordUsage(entry: entry)
            onShowNotification?("已复制，原应用未恢复焦点，请手动粘贴 (⌘V)", true)
            return
        }

        // Step 4: Attempt auto-paste
        let pasteResult = pasteService.attemptPaste()

        switch pasteResult {
        case .dispatched:
            PPLogger.execute.info("Auto-paste succeeded for entry \(entry.id)")
            logExecution(
                entry: entry,
                projectId: projectId,
                frontAppBundleId: frontAppBundleId,
                observedAppBundleId: observedAppBundleId,
                clipboardSuccess: true,
                pasteAttempted: true,
                pasteSuccess: true,
                result: .success,
                totalDurationMs: elapsedMilliseconds(since: startTime)
            )
            recordUsage(entry: entry)
            // No notification needed on success — user sees content appear
        case .accessibilityNotGranted:
            PPLogger.execute.warning("Accessibility permission disappeared before paste for entry \(entry.id)")
            logExecution(
                entry: entry,
                projectId: projectId,
                frontAppBundleId: frontAppBundleId,
                observedAppBundleId: observedAppBundleId,
                clipboardSuccess: true,
                pasteAttempted: true,
                pasteSuccess: false,
                result: .clipboardOnly,
                failureReason: .accessibilityNotGranted,
                totalDurationMs: elapsedMilliseconds(since: startTime)
            )
            recordUsage(entry: entry)
            onShowNotification?("已复制到剪贴板，可手动粘贴 (⌘V)", true)
        case .eventCreationFailed:
            PPLogger.execute.warning("Auto-paste event creation failed for entry \(entry.id); clipboard fallback")
            logExecution(
                entry: entry,
                projectId: projectId,
                frontAppBundleId: frontAppBundleId,
                observedAppBundleId: observedAppBundleId,
                clipboardSuccess: true,
                pasteAttempted: true,
                pasteSuccess: false,
                result: .clipboardOnly,
                failureReason: .pasteEventCreationFailed,
                totalDurationMs: elapsedMilliseconds(since: startTime)
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
        observedAppBundleId: String?,
        clipboardSuccess: Bool,
        pasteAttempted: Bool,
        pasteSuccess: Bool,
        result: Constants.ExecutionResult,
        failureReason: Constants.ExecutionFailureReason? = nil,
        totalDurationMs: Int? = nil
    ) {
        let log = ExecutionLog(
            entryId: entry.id,
            projectId: projectId,
            frontAppBundleId: frontAppBundleId,
            observedAppBundleId: observedAppBundleId,
            hasAccessibility: permissionService.isAccessibilityGranted,
            clipboardSuccess: clipboardSuccess,
            pasteAttempted: pasteAttempted,
            pasteSuccess: pasteSuccess,
            result: result.rawValue,
            failureReason: failureReason?.rawValue,
            totalDurationMs: totalDurationMs
        )
        do {
            try logRepository.record(log)
        } catch {
            PPLogger.execute.error("Failed to write execution log: \(error.localizedDescription)")
        }
    }

    private func elapsedMilliseconds(since startTime: UInt64) -> Int {
        Int((DispatchTime.now().uptimeNanoseconds - startTime) / 1_000_000)
    }
}
