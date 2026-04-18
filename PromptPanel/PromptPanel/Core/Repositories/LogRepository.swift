import Foundation
import GRDB

/// Data access layer for execution logs.
final class LogRepository {

    private let dbQueue: DatabaseQueue

    init(dbQueue: DatabaseQueue) {
        self.dbQueue = dbQueue
    }

    /// Record an execution log entry.
    func record(_ log: ExecutionLog) throws {
        try dbQueue.write { db in
            try log.insert(db)
        }
        PPLogger.execute.info("Execution logged: entry=\(log.entryId), result=\(log.result)")
    }

    /// Fetch recent execution logs (for debugging).
    func fetchRecent(limit: Int = 100) throws -> [ExecutionLog] {
        try dbQueue.read { db in
            try ExecutionLog
                .order(ExecutionLog.Columns.createdAt.desc)
                .limit(limit)
                .fetchAll(db)
        }
    }

    /// Clean up old logs (keep only last N days).
    func cleanup(olderThanDays days: Int = 30) throws {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        try dbQueue.write { db in
            try db.execute(
                sql: "DELETE FROM execution_logs WHERE created_at < ?",
                arguments: [cutoff]
            )
        }
        PPLogger.execute.info("Cleaned up logs older than \(days) days")
    }
}
