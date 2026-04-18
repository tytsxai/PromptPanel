import Foundation

/// Global constants for PromptPanel
enum Constants {

    // MARK: - Application Identity

    static let appName = "PromptPanel"
    static let bundleIdentifier = "com.promptpanel.app"

    // MARK: - Data Directories

    static var applicationSupportDirectory: URL {
        let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent(appName)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static var databaseURL: URL {
        applicationSupportDirectory.appendingPathComponent("promptpanel.db")
    }

    // MARK: - Log Directories

    static var logsDirectory: URL {
        let url = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Logs")
            .appendingPathComponent(appName)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

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
}
