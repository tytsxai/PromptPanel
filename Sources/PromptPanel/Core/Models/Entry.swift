import Foundation
import GRDB

/// Represents an entry (snippet/template) that can be quickly executed via the panel.
struct Entry: Identifiable, Codable, Equatable {
    /// Unique identifier (UUID string).
    var id: String
    /// The project this entry belongs to.
    var projectId: String
    /// Display title.
    var title: String
    /// Full content (supports multi-line).
    var content: String
    /// Entry type for data categorization (V1: no filtering/sorting by type).
    var type: String
    /// Whether this entry is pinned to the top.
    var isPinned: Bool
    /// Manual sort order value (higher = appears first).
    var sortOrder: Int
    /// Number of times this entry has been used.
    var useCount: Int
    /// Last time this entry was used (nil if never used).
    var lastUsedAt: Date?
    /// Creation timestamp.
    var createdAt: Date
    /// Last update timestamp.
    var updatedAt: Date

    init(
        id: String = UUID().uuidString,
        projectId: String,
        title: String,
        content: String,
        type: String = Constants.EntryType.prompt.rawValue,
        isPinned: Bool = false,
        sortOrder: Int = 0,
        useCount: Int = 0,
        lastUsedAt: Date? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.projectId = projectId
        self.title = title
        self.content = content
        self.type = type
        self.isPinned = isPinned
        self.sortOrder = sortOrder
        self.useCount = useCount
        self.lastUsedAt = lastUsedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case projectId = "project_id"
        case title
        case content
        case type
        case isPinned = "is_pinned"
        case sortOrder = "sort_order"
        case useCount = "use_count"
        case lastUsedAt = "last_used_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - GRDB Conformance

extension Entry: FetchableRecord, PersistableRecord {
    static let databaseTableName = "entries"

    enum Columns: String, ColumnExpression {
        case id
        case projectId = "project_id"
        case title
        case content
        case type
        case isPinned = "is_pinned"
        case sortOrder = "sort_order"
        case useCount = "use_count"
        case lastUsedAt = "last_used_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
