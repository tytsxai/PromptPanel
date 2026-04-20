import Foundation
import GRDB

/// All database schema migrations, registered in order.
enum Migrations {

    /// Register all migrations with the migrator.
    static func registerAll(_ migrator: inout DatabaseMigrator) {
        registerV1(migrator: &migrator)
        registerV2ExecutionLogDiagnostics(migrator: &migrator)
        registerV3ExecutionLogInteractionDiagnostics(migrator: &migrator)
        registerV4EntryTags(migrator: &migrator)
        registerV5DropUnusedEntryTagsIndex(migrator: &migrator)
    }

    // MARK: - V1: Initial Schema

    private static func registerV1(migrator: inout DatabaseMigrator) {
        migrator.registerMigration("v1_create_tables") { db in
            PPLogger.database.info("Running migration: v1_create_tables")

            // ----- projects -----
            try db.create(table: "projects") { t in
                t.column("id", .text).notNull().primaryKey()
                t.column("name", .text).notNull()
                t.column("is_default", .boolean).notNull().defaults(to: false)
                t.column("created_at", .datetime).notNull()
                t.column("updated_at", .datetime).notNull()
            }

            // ----- entries -----
            try db.create(table: "entries") { t in
                t.column("id", .text).notNull().primaryKey()
                t.column("project_id", .text).notNull()
                    .references("projects", onDelete: .restrict)
                t.column("title", .text).notNull()
                t.column("content", .text).notNull()
                t.column("type", .text).notNull().defaults(to: "prompt")
                t.column("is_pinned", .boolean).notNull().defaults(to: false)
                t.column("sort_order", .integer).notNull().defaults(to: 0)
                t.column("use_count", .integer).notNull().defaults(to: 0)
                t.column("last_used_at", .datetime)
                t.column("created_at", .datetime).notNull()
                t.column("updated_at", .datetime).notNull()
            }
            try db.create(indexOn: "entries", columns: ["project_id"])

            // ----- entries_fts (FTS5 for full-text search) -----
            try db.execute(sql: """
                CREATE VIRTUAL TABLE entries_fts USING fts5(
                    title,
                    content,
                    content='entries',
                    content_rowid='rowid'
                )
                """)

            // FTS sync triggers: keep entries_fts in sync with entries
            try db.execute(sql: """
                CREATE TRIGGER entries_ai AFTER INSERT ON entries BEGIN
                    INSERT INTO entries_fts(rowid, title, content)
                    VALUES (new.rowid, new.title, new.content);
                END
                """)
            try db.execute(sql: """
                CREATE TRIGGER entries_ad AFTER DELETE ON entries BEGIN
                    INSERT INTO entries_fts(entries_fts, rowid, title, content)
                    VALUES ('delete', old.rowid, old.title, old.content);
                END
                """)
            try db.execute(sql: """
                CREATE TRIGGER entries_au AFTER UPDATE ON entries BEGIN
                    INSERT INTO entries_fts(entries_fts, rowid, title, content)
                    VALUES ('delete', old.rowid, old.title, old.content);
                    INSERT INTO entries_fts(rowid, title, content)
                    VALUES (new.rowid, new.title, new.content);
                END
                """)

            // ----- app_settings -----
            try db.create(table: "app_settings") { t in
                t.column("key", .text).notNull().primaryKey()
                t.column("value", .text)
            }

            // ----- execution_logs -----
            try db.create(table: "execution_logs") { t in
                t.column("id", .text).notNull().primaryKey()
                t.column("entry_id", .text).notNull()
                t.column("project_id", .text).notNull()
                t.column("front_app_bundle_id", .text)
                t.column("has_accessibility", .boolean).notNull()
                t.column("clipboard_success", .boolean).notNull()
                t.column("paste_attempted", .boolean).notNull()
                t.column("paste_success", .boolean).notNull()
                t.column("result", .text).notNull()
                t.column("created_at", .datetime).notNull()
            }
            try db.create(indexOn: "execution_logs", columns: ["created_at"])

            // ----- Seed: Create the default project ("通用项目") -----
            let now = Date()
            let defaultProject = Project(
                name: Constants.defaultProjectName,
                isDefault: true,
                createdAt: now,
                updatedAt: now
            )
            try defaultProject.insert(db)
            PPLogger.database.info("Default project created with ID: \(defaultProject.id)")

            // Persist the default project as current project
            try AppSetting(key: Constants.SettingsKey.currentProjectId, value: defaultProject.id).insert(db)
        }
    }

    private static func registerV2ExecutionLogDiagnostics(migrator: inout DatabaseMigrator) {
        migrator.registerMigration("v2_execution_log_diagnostics") { db in
            PPLogger.database.info("Running migration: v2_execution_log_diagnostics")

            try db.alter(table: "execution_logs") { t in
                t.add(column: "observed_app_bundle_id", .text)
                t.add(column: "failure_reason", .text)
                t.add(column: "total_duration_ms", .integer)
            }
        }
    }

    private static func registerV3ExecutionLogInteractionDiagnostics(migrator: inout DatabaseMigrator) {
        migrator.registerMigration("v3_execution_log_interaction_diagnostics") { db in
            PPLogger.database.info("Running migration: v3_execution_log_interaction_diagnostics")

            try db.alter(table: "execution_logs") { t in
                t.add(column: "trigger_source", .text)
                t.add(column: "target_app_restore_duration_ms", .integer)
            }
        }
    }

    private static func registerV4EntryTags(migrator: inout DatabaseMigrator) {
        migrator.registerMigration("v4_entry_tags") { db in
            PPLogger.database.info("Running migration: v4_entry_tags")

            try db.alter(table: "entries") { t in
                // Tags are stored as a JSON array of strings, e.g. ["发布", "检查清单"].
                // Empty string ("[]") is treated the same as NULL / no tags.
                t.add(column: "tags", .text).notNull().defaults(to: "[]")
            }
        }
    }

    private static func registerV5DropUnusedEntryTagsIndex(migrator: inout DatabaseMigrator) {
        migrator.registerMigration("v5_drop_unused_entry_tags_index") { db in
            PPLogger.database.info("Running migration: v5_drop_unused_entry_tags_index")
            try db.execute(sql: "DROP INDEX IF EXISTS index_entries_on_tags")
        }
    }
}
