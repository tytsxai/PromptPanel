import Foundation
import GRDB

/// Manages the SQLite database lifecycle: creation, migration, and access.
final class DatabaseManager {

    /// The shared database queue for all read/write operations.
    let dbQueue: DatabaseQueue

    /// Initialize with a database at the specified URL.
    /// - Parameter url: Path to the SQLite database file. If nil, uses the default path.
    init(url: URL? = nil) throws {
        let databaseURL = url ?? Constants.databaseURL
        PPLogger.database.info("Opening database at \(databaseURL.path)")

        // Ensure the parent directory exists
        let directory = databaseURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        // Configure the database
        var config = Configuration()
        #if DEBUG
        config.prepareDatabase { db in
            db.trace { PPLogger.database.debug("\($0)") }
        }
        #endif

        dbQueue = try DatabaseQueue(path: databaseURL.path, configuration: config)

        // Enable WAL mode for better read/write concurrency
        try dbQueue.write { db in
            try db.execute(sql: "PRAGMA journal_mode = WAL")
        }

        // Run migrations
        try runMigrations()

        PPLogger.database.info("Database initialized successfully")
    }

    /// Run all database migrations in order.
    private func runMigrations() throws {
        var migrator = DatabaseMigrator()

        // Always re-run migrations in development to catch issues early
        #if DEBUG
        migrator.eraseDatabaseOnSchemaChange = true
        #endif

        // Register all migrations
        Migrations.registerAll(&migrator)

        // Apply pending migrations
        try migrator.migrate(dbQueue)

        PPLogger.database.info("Migrations completed")
    }
}
