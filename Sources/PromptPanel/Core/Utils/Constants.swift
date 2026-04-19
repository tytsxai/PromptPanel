import AppKit
import Foundation
import SwiftUI

/// Global constants for PromptPanel
enum Constants {
    private static let appSupportOverrideEnv = "PROMPTPANEL_APP_SUPPORT_DIR"
    private static let logsOverrideEnv = "PROMPTPANEL_LOGS_DIR"

    // MARK: - Visual system (PromptPanel front-end baseline)
    enum VisualStyle {
        static let bg = Color(red: 0x0e / 255.0, green: 0x0f / 255.0, blue: 0x11 / 255.0)
        static let surface = Color(red: 0x17 / 255.0, green: 0x18 / 255.0, blue: 0x1b / 255.0)
        static let surfaceRaised = Color(red: 0x1e / 255.0, green: 0x1f / 255.0, blue: 0x23 / 255.0)
        static let surfaceHover = Color(red: 0x24 / 255.0, green: 0x26 / 255.0, blue: 0x2b / 255.0)
        static let surfaceActive = Color(red: 0x2b / 255.0, green: 0x2e / 255.0, blue: 0x34 / 255.0)
        static let sidebar = Color(red: 0x14 / 255.0, green: 0x15 / 255.0, blue: 0x18 / 255.0)
        static let border = Color.white.opacity(0.06)
        static let borderStrong = Color.white.opacity(0.10)
        static let divider = Color.white.opacity(0.04)

        static let text = Color(red: 0xe8 / 255.0, green: 0xe9 / 255.0, blue: 0xec / 255.0)
        static let textSecondary = Color(red: 0x9a / 255.0, green: 0x9e / 255.0, blue: 0xa6 / 255.0)
        static let textTertiary = Color(red: 0x6b / 255.0, green: 0x6f / 255.0, blue: 0x77 / 255.0)
        static let textQuaternary = Color(red: 0x4a / 255.0, green: 0x4d / 255.0, blue: 0x54 / 255.0)

        static let accent = Color(red: 0x7c / 255.0, green: 0x8c / 255.0, blue: 0xf8 / 255.0)
        static let accentDim = Color(red: 0x7c / 255.0, green: 0x8c / 255.0, blue: 0xf8 / 255.0).opacity(0.14)
        static let accentBorder = Color(red: 0x7c / 255.0, green: 0x8c / 255.0, blue: 0xf8 / 255.0).opacity(0.35)

        static let success = Color(red: 0x5f / 255.0, green: 0xb3 / 255.0, blue: 0x7a / 255.0)
        static let successDim = Color(red: 0x5f / 255.0, green: 0xb3 / 255.0, blue: 0x7a / 255.0).opacity(0.12)
        static let warn = Color(red: 0xd4 / 255.0, green: 0xa3 / 255.0, blue: 0x5a / 255.0)
        static let warnDim = Color(red: 0xd4 / 255.0, green: 0xa3 / 255.0, blue: 0x5a / 255.0).opacity(0.12)
        static let danger = Color(red: 0xd4 / 255.0, green: 0x70 / 255.0, blue: 0x70 / 255.0)
        static let dangerDim = Color(red: 0xd4 / 255.0, green: 0x70 / 255.0, blue: 0x70 / 255.0).opacity(0.12)
    }

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
        static let panelShowFooter = "panel_show_footer"
        static let panelCompactRows = "panel_compact_rows"
        static let closePanelAfterExecute = "close_panel_after_execute"
    }

    // MARK: - Entry Types

    enum EntryType: String, CaseIterable, Codable {
        case prompt
        case code
        case reply
        case note

        var displayName: String {
            switch self {
            case .prompt: return "Prompt"
            case .code: return "代码"
            case .reply: return "回复"
            case .note: return "说明"
            }
        }

        var symbolName: String {
            switch self {
            case .prompt: return "text.bubble.fill"
            case .code: return "chevron.left.forwardslash.chevron.right"
            case .reply: return "arrowshape.turn.up.left.fill"
            case .note: return "note.text"
            }
        }

        var accentColor: Color {
            switch self {
            case .prompt: return Color(red: 0.36, green: 0.62, blue: 0.95)
            case .code: return Color(red: 0.36, green: 0.78, blue: 0.56)
            case .reply: return Color(red: 0.96, green: 0.65, blue: 0.30)
            case .note: return Color(red: 0.65, green: 0.55, blue: 0.86)
            }
        }

        static func resolve(_ rawValue: String?) -> EntryType {
            guard let rawValue, let parsed = EntryType(rawValue: rawValue) else {
                return .prompt
            }
            return parsed
        }
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

    enum MainWindowLayout {
        static let defaultContentSize = NSSize(width: 1100, height: 740)
        static let minContentSize = NSSize(width: 1020, height: 680)
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
