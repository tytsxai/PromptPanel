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

    // MARK: - Panel Performance

    static let panelOpenLatencyTargetMs = 300
    static let panelExecutionUnlockDelayMs = 50

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
