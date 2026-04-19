import AppKit
import Foundation

/// Global constants for PromptPanel
enum Constants {
    private static let appSupportOverrideEnv = "PROMPTPANEL_APP_SUPPORT_DIR"
    private static let logsOverrideEnv = "PROMPTPANEL_LOGS_DIR"

    // MARK: - Application Identity

    static let appName = "PromptPanel"
    static let bundleIdentifier = "com.promptpanel.app"

    // MARK: - Data Directories

    static var applicationSupportDirectory: URL {
        let url = environmentURL(for: appSupportOverrideEnv)
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
                .appendingPathComponent(appName)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static var databaseURL: URL {
        applicationSupportDirectory.appendingPathComponent("promptpanel.db")
    }

    static func backupDirectory(for databaseURL: URL) -> URL {
        storageRoot(for: databaseURL).appendingPathComponent("Backups", isDirectory: true)
    }

    static func recoveryDirectory(for databaseURL: URL) -> URL {
        storageRoot(for: databaseURL).appendingPathComponent("Recovery", isDirectory: true)
    }

    // MARK: - Log Directories

    static var logsDirectory: URL {
        let url = environmentURL(for: logsOverrideEnv)
            ?? FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!
                .appendingPathComponent("Logs")
                .appendingPathComponent(appName)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static let automaticBackupRetentionCount = 7
    static let automaticBackupMinimumInterval: TimeInterval = 12 * 60 * 60
    static let executionLogRetentionDays = 30
    static let secureDirectoryPermissions = 0o700
    static let secureFilePermissions = 0o600

    // MARK: - Default Project

    static let defaultProjectName = "通用项目"

    // MARK: - Settings Keys

    enum SettingsKey {
        static let currentProjectId = "current_project_id"
        static let panelPinned = "panel_pinned"
        static let panelContentWidth = "panel_content_width"
        static let panelContentHeight = "panel_content_height"
    }

    // MARK: - Entry Types

    enum EntryType: String, CaseIterable, Codable {
        case prompt
        case code
        case reply
        case note
    }

    // MARK: - Execution Results

    enum ExecutionResult: String, Codable {
        case success
        case clipboardOnly = "clipboard_only"
        case failed
    }

    enum ExecutionTrigger: String, Codable {
        case keyboardSubmit = "keyboard_submit"
        case pointerClick = "pointer_click"
    }

    // MARK: - Panel Performance

    enum Interface {
        static let outerPadding: CGFloat = 10
        static let contentPadding: CGFloat = 10
        static let sectionSpacing: CGFloat = 10
        static let itemSpacing: CGFloat = 8
        static let rowSpacing: CGFloat = 4
        static let cardCornerRadius: CGFloat = 10
        static let controlCornerRadius: CGFloat = 8
    }

    enum MainWindowLayout {
        static let defaultContentSize = NSSize(width: 1080, height: 700)
        static let minContentSize = NSSize(width: 1020, height: 680)
        static let sidebarRowHeight: CGFloat = 44
        static let sidebarListMaxHeight: CGFloat = 288
    }

    enum PanelLayout {
        static let outerPadding: CGFloat = 4
        static let headerSpacing: CGFloat = 4
        static let controlHeight: CGFloat = 22
        static let projectControlWidth: CGFloat = 112
        static let surfaceCornerRadius: CGFloat = 12
        static let sectionCornerRadius: CGFloat = 10
        static let rowHeight: CGFloat = 32
        static let loadingMinHeight: CGFloat = 64
        static let emptyStateMinHeight: CGFloat = 48
        static let statusHeight: CGFloat = 24
    }

    static let panelContentInsets = NSEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
    static let panelContentSize = NSSize(width: 680, height: 384)
    static let panelMinContentSize = NSSize(width: 560, height: 300)
    static let panelMaxContentSize = NSSize(width: 1120, height: 760)
    static func panelWindowContentSize(for panelContentSize: NSSize) -> NSSize {
        NSSize(
            width: panelContentSize.width + panelContentInsets.left + panelContentInsets.right,
            height: panelContentSize.height + panelContentInsets.top + panelContentInsets.bottom
        )
    }
    static var panelWindowSize: NSSize {
        panelWindowContentSize(for: panelContentSize)
    }
    static let panelOpenLatencyTargetMs = 300
    static let panelExecutionUnlockDelayMs = 50
    static let panelActivationRetryDelayMs = 60
    static let panelActivationMaxAttempts = 8
    static let panelFocusRetryDelayMs = 60
    static let panelFocusMaxAttempts = 10
    static let panelDeactivateCloseGraceMs = 900
    static let panelSearchDebounceMs = 80
    static let mainWindowSearchDebounceMs = 120
    static let searchLatencyTargetMs = 80
    static let executionLatencyTargetMs = 250
    static let targetAppRestorePollIntervalMs = 40
    static let targetAppRestoreTimeoutMs = 700

    enum ExecutionFailureReason: String, Codable {
        case clipboardWriteFailed = "clipboard_write_failed"
        case accessibilityNotGranted = "accessibility_not_granted"
        case targetAppNotRestored = "target_app_not_restored"
        case pasteEventCreationFailed = "paste_event_creation_failed"
    }

    private static func storageRoot(for databaseURL: URL) -> URL {
        let normalizedDatabaseURL = databaseURL.standardizedFileURL
        if normalizedDatabaseURL == self.databaseURL.standardizedFileURL {
            return applicationSupportDirectory
        }
        return normalizedDatabaseURL.deletingLastPathComponent()
    }

    private static func environmentURL(for key: String) -> URL? {
        let rawValue = ProcessInfo.processInfo.environment[key]?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let rawValue, !rawValue.isEmpty else {
            return nil
        }
        return URL(fileURLWithPath: rawValue, isDirectory: true)
    }
}
