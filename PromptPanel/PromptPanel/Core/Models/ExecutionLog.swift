import Foundation
import GRDB

/// Minimal execution log for debugging paste failures.
/// IMPORTANT: Does NOT store entry content to protect user privacy.
struct ExecutionLog: Identifiable, Codable {
    /// Unique identifier.
    var id: String
    /// The entry that was executed.
    var entryId: String
    /// The active project at execution time.
    var projectId: String
    /// Bundle ID of the frontmost application.
    var frontAppBundleId: String?
    /// Bundle ID observed right before auto-paste dispatch.
    var observedAppBundleId: String?
    /// Whether accessibility permission was available.
    var hasAccessibility: Bool
    /// Whether clipboard write succeeded.
    var clipboardSuccess: Bool
    /// Whether auto-paste was attempted.
    var pasteAttempted: Bool
    /// Whether auto-paste succeeded.
    var pasteSuccess: Bool
    /// Final execution result.
    var result: String
    /// More precise failure classification for clipboard fallback or failures.
    var failureReason: String?
    /// Total execution duration in milliseconds.
    var totalDurationMs: Int?
    /// Execution timestamp.
    var createdAt: Date

    init(
        id: String = UUID().uuidString,
        entryId: String,
        projectId: String,
        frontAppBundleId: String? = nil,
        observedAppBundleId: String? = nil,
        hasAccessibility: Bool,
        clipboardSuccess: Bool,
        pasteAttempted: Bool,
        pasteSuccess: Bool,
        result: String,
        failureReason: String? = nil,
        totalDurationMs: Int? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.entryId = entryId
        self.projectId = projectId
        self.frontAppBundleId = frontAppBundleId
        self.observedAppBundleId = observedAppBundleId
        self.hasAccessibility = hasAccessibility
        self.clipboardSuccess = clipboardSuccess
        self.pasteAttempted = pasteAttempted
        self.pasteSuccess = pasteSuccess
        self.result = result
        self.failureReason = failureReason
        self.totalDurationMs = totalDurationMs
        self.createdAt = createdAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case entryId = "entry_id"
        case projectId = "project_id"
        case frontAppBundleId = "front_app_bundle_id"
        case observedAppBundleId = "observed_app_bundle_id"
        case hasAccessibility = "has_accessibility"
        case clipboardSuccess = "clipboard_success"
        case pasteAttempted = "paste_attempted"
        case pasteSuccess = "paste_success"
        case result
        case failureReason = "failure_reason"
        case totalDurationMs = "total_duration_ms"
        case createdAt = "created_at"
    }
}

// MARK: - GRDB Conformance

extension ExecutionLog: FetchableRecord, PersistableRecord {
    static let databaseTableName = "execution_logs"

    enum Columns: String, ColumnExpression {
        case id
        case entryId = "entry_id"
        case projectId = "project_id"
        case frontAppBundleId = "front_app_bundle_id"
        case observedAppBundleId = "observed_app_bundle_id"
        case hasAccessibility = "has_accessibility"
        case clipboardSuccess = "clipboard_success"
        case pasteAttempted = "paste_attempted"
        case pasteSuccess = "paste_success"
        case result
        case failureReason = "failure_reason"
        case totalDurationMs = "total_duration_ms"
        case createdAt = "created_at"
    }
}
