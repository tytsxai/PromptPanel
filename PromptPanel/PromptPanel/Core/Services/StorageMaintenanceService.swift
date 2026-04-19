import AppKit
import Foundation
import GRDB

struct LaunchRecoveryReport {
    let quarantinedFilesDirectoryURL: URL
    let recoveredAt: Date
    let failureDescription: String

    var userFacingMessage: String {
        "检测到本地数据库异常，旧数据已隔离到 \(quarantinedFilesDirectoryURL.lastPathComponent)，应用已重建可用数据库。请优先检查最近备份。"
    }
}

struct StorageHealthSnapshot {
    let databaseURL: URL
    let backupDirectoryURL: URL
    let recoveryDirectoryURL: URL
    let logsDirectoryURL: URL
    let databaseSizeBytes: Int64
    let backupCount: Int
    let latestBackupURL: URL?
}

final class StorageMaintenanceService: @unchecked Sendable {
    private let dbQueue: DatabaseQueue
    private let logRepository: LogRepository
    private let databaseURL: URL
    private let fileManager: FileManager

    init(
        dbQueue: DatabaseQueue,
        logRepository: LogRepository,
        databaseURL: URL,
        fileManager: FileManager = .default
    ) {
        self.dbQueue = dbQueue
        self.logRepository = logRepository
        self.databaseURL = databaseURL
        self.fileManager = fileManager
    }

    @discardableResult
    func performLaunchMaintenance() throws -> StorageHealthSnapshot {
        try ensureStorageDirectories()
        try checkpointWal()
        try logRepository.cleanup(olderThanDays: Constants.executionLogRetentionDays)
        if try shouldCreateAutomaticBackup() {
            _ = try createBackup(reason: "launch")
        }
        try pruneBackups(keeping: Constants.automaticBackupRetentionCount)
        return try healthSnapshot()
    }

    func prepareForTermination() {
        do {
            try checkpointWal()
        } catch {
            PPLogger.database.error("Failed to checkpoint database during termination: \(error.localizedDescription)")
        }
    }

    func createManualBackup() throws -> URL {
        try ensureStorageDirectories()
        try checkpointWal()
        let backupURL = try createBackup(reason: "manual")
        try pruneBackups(keeping: Constants.automaticBackupRetentionCount)
        return backupURL
    }

    func healthSnapshot() throws -> StorageHealthSnapshot {
        try ensureStorageDirectories()

        let backups = try backupFiles()
        let databaseSizeBytes = (try fileSize(at: databaseURL)) ?? 0

        return StorageHealthSnapshot(
            databaseURL: databaseURL,
            backupDirectoryURL: Constants.backupDirectory(for: databaseURL),
            recoveryDirectoryURL: Constants.recoveryDirectory(for: databaseURL),
            logsDirectoryURL: Constants.logsDirectory,
            databaseSizeBytes: databaseSizeBytes,
            backupCount: backups.count,
            latestBackupURL: backups.first
        )
    }

    func openDatabaseDirectory() {
        fileManager.ensureDirectoryExists(
            at: databaseURL.deletingLastPathComponent(),
            permissions: Constants.secureDirectoryPermissions
        )
        NSWorkspace.shared.activateFileViewerSelecting([databaseURL])
    }

    func openBackupDirectory() {
        let backupDirectoryURL = Constants.backupDirectory(for: databaseURL)
        fileManager.ensureDirectoryExists(at: backupDirectoryURL, permissions: Constants.secureDirectoryPermissions)
        NSWorkspace.shared.open(backupDirectoryURL)
    }

    private func shouldCreateAutomaticBackup() throws -> Bool {
        guard let latestBackupURL = try backupFiles().first else {
            return true
        }
        guard let modificationDate = try latestBackupURL.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate else {
            return true
        }
        return Date().timeIntervalSince(modificationDate) >= Constants.automaticBackupMinimumInterval
    }

    private func createBackup(reason: String) throws -> URL {
        let backupDirectoryURL = Constants.backupDirectory(for: databaseURL)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let timestamp = formatter.string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let filename = "promptpanel-\(timestamp)-\(reason)-\(UUID().uuidString.prefix(8)).sqlite"
        let destinationURL = backupDirectoryURL.appendingPathComponent(filename)

        try? fileManager.removeItem(at: destinationURL)
        do {
            let destinationQueue = try DatabaseQueue(path: destinationURL.path)
            try dbQueue.backup(to: destinationQueue)
            try secureItem(at: destinationURL, isDirectory: false)
            PPLogger.database.info("Database backup created at \(destinationURL.lastPathComponent)")
            return destinationURL
        } catch {
            try? fileManager.removeItem(at: destinationURL)
            PPLogger.database.error("Failed to create database backup: \(error.localizedDescription)")
            throw error
        }
    }

    private func pruneBackups(reason: String? = nil, keeping count: Int) throws {
        let backups = try backupFiles(reason: reason)
        guard backups.count > count else {
            return
        }

        for backupURL in backups.dropFirst(count) {
            try? fileManager.removeItem(at: backupURL)
        }
    }

    private func backupFiles(reason: String? = nil) throws -> [URL] {
        let directoryURL = Constants.backupDirectory(for: databaseURL)
        guard let enumerator = fileManager.enumerator(
            at: directoryURL,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        let urls = enumerator.compactMap { $0 as? URL }.filter { url in
            guard url.pathExtension == "sqlite" else {
                return false
            }
            guard let reason else {
                return true
            }
            return url.lastPathComponent.contains("-\(reason)-")
        }
        return try urls.sorted { lhs, rhs in
            let lhsDate = try lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate ?? .distantPast
            let rhsDate = try rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate ?? .distantPast
            return lhsDate > rhsDate
        }
    }

    private func checkpointWal() throws {
        try dbQueue.writeWithoutTransaction { db in
            _ = try db.checkpoint(.truncate)
        }
    }

    private func ensureStorageDirectories() throws {
        try secureItem(at: databaseURL.deletingLastPathComponent(), isDirectory: true)
        try secureItem(at: Constants.backupDirectory(for: databaseURL), isDirectory: true)
        try secureItem(at: Constants.recoveryDirectory(for: databaseURL), isDirectory: true)
        try secureItem(at: Constants.logsDirectory, isDirectory: true)
    }

    private func fileSize(at url: URL) throws -> Int64? {
        guard fileManager.fileExists(atPath: url.path) else {
            return nil
        }
        let attributes = try fileManager.attributesOfItem(atPath: url.path)
        return (attributes[.size] as? NSNumber)?.int64Value
    }

    private func secureItem(at url: URL, isDirectory: Bool) throws {
        let permissions = isDirectory ? Constants.secureDirectoryPermissions : Constants.secureFilePermissions
        if isDirectory {
            try fileManager.createDirectory(
                at: url,
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: permissions]
            )
        }
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.setAttributes([.posixPermissions: permissions], ofItemAtPath: url.path)
        }
    }
}

private extension FileManager {
    func ensureDirectoryExists(at url: URL, permissions: Int) {
        try? createDirectory(
            at: url,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: permissions]
        )
    }
}
