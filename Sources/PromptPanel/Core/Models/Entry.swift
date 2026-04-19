import Foundation
import GRDB

/// Represents an entry (snippet/template) that can be quickly executed via the panel.
struct Entry: Identifiable, Codable, Equatable {
    var id: String
    var projectId: String
    var title: String
    var content: String
    var type: String
    var isPinned: Bool
    var sortOrder: Int
    var useCount: Int
    var lastUsedAt: Date?
    var createdAt: Date
    var updatedAt: Date
    /// Free-form short labels. Stored as JSON array of strings in the `tags` column.
    var tags: [String]

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
        updatedAt: Date = Date(),
        tags: [String] = []
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
        self.tags = Entry.normalizeTags(tags)
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
        case tags
    }

    static func normalizeTags(_ tags: [String]) -> [String] {
        var seen = Set<String>()
        var out: [String] = []
        for raw in tags {
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            if seen.insert(trimmed).inserted {
                out.append(trimmed)
            }
        }
        return out
    }
}

// MARK: - GRDB Conformance (custom encoding so [String] <-> JSON in SQLite)

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
        case tags
    }

    init(row: Row) throws {
        self.id = row["id"]
        self.projectId = row["project_id"]
        self.title = row["title"]
        self.content = row["content"]
        self.type = row["type"]
        self.isPinned = row["is_pinned"]
        self.sortOrder = row["sort_order"]
        self.useCount = row["use_count"]
        self.lastUsedAt = row["last_used_at"]
        self.createdAt = row["created_at"]
        self.updatedAt = row["updated_at"]
        self.tags = EntryTagsCodec.decode(row["tags"])
    }

    func encode(to container: inout PersistenceContainer) throws {
        container["id"] = id
        container["project_id"] = projectId
        container["title"] = title
        container["content"] = content
        container["type"] = type
        container["is_pinned"] = isPinned
        container["sort_order"] = sortOrder
        container["use_count"] = useCount
        container["last_used_at"] = lastUsedAt
        container["created_at"] = createdAt
        container["updated_at"] = updatedAt
        container["tags"] = EntryTagsCodec.encode(tags)
    }
}

/// JSON <-> `[String]` codec for the `entries.tags` column.
/// Malformed JSON falls back to an empty list so a single bad row cannot crash the app.
enum EntryTagsCodec {
    static func encode(_ tags: [String]) -> String {
        let normalized = Entry.normalizeTags(tags)
        guard let data = try? JSONEncoder().encode(normalized),
              let string = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return string
    }

    static func decode(_ raw: String?) -> [String] {
        guard let raw,
              let data = raw.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return Entry.normalizeTags(decoded)
    }
}
