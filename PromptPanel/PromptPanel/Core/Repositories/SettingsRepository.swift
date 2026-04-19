import Foundation
import GRDB

/// Data access layer for app settings (key-value store).
final class SettingsRepository: @unchecked Sendable {

    private let dbQueue: DatabaseQueue

    init(dbQueue: DatabaseQueue) {
        self.dbQueue = dbQueue
    }

    /// Get a setting value by key.
    func get(_ key: String) throws -> String? {
        try dbQueue.read { db in
            try AppSetting
                .filter(AppSetting.Columns.key == key)
                .fetchOne(db)?
                .value
        }
    }

    /// Set a setting value.
    func set(_ key: String, value: String?) throws {
        try dbQueue.write { db in
            let setting = AppSetting(key: key, value: value)
            try setting.save(db)
        }
    }

    // MARK: - Convenience

    func getCurrentProjectId() throws -> String? {
        try get(Constants.SettingsKey.currentProjectId)
    }

    func setCurrentProjectId(_ id: String) throws {
        try set(Constants.SettingsKey.currentProjectId, value: id)
        PPLogger.project.info("Current project set to: \(id)")
    }

    func getBool(_ key: String, default defaultValue: Bool = false) throws -> Bool {
        guard let rawValue = try get(key) else {
            return defaultValue
        }

        switch rawValue.lowercased() {
        case "1", "true", "yes", "on":
            return true
        case "0", "false", "no", "off":
            return false
        default:
            return defaultValue
        }
    }

    func setBool(_ key: String, value: Bool) throws {
        try set(key, value: value ? "1" : "0")
    }

    func isPanelPinned() throws -> Bool {
        try getBool(Constants.SettingsKey.panelPinned)
    }

    func setPanelPinned(_ isPinned: Bool) throws {
        try setBool(Constants.SettingsKey.panelPinned, value: isPinned)
        PPLogger.panel.info("Panel pinned set to: \(isPinned)")
    }
}
