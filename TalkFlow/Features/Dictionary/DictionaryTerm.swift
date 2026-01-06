import Foundation
import GRDB

struct DictionaryTerm: Codable, Identifiable, Hashable, FetchableRecord, PersistableRecord, Sendable {
    var id: Int64?
    var term: String
    var isEnabled: Bool
    var createdAt: Date
    var updatedAt: Date

    static let databaseTableName = "dictionary_terms"

    init(id: Int64? = nil, term: String, isEnabled: Bool = true, createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.id = id
        self.term = term
        self.isEnabled = isEnabled
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    // MARK: - FetchableRecord

    init(row: Row) {
        id = row["id"]
        term = row["term"]
        isEnabled = row["is_enabled"]
        createdAt = row["created_at"]
        updatedAt = row["updated_at"]
    }

    // MARK: - PersistableRecord

    func encode(to container: inout PersistenceContainer) {
        container["id"] = id
        container["term"] = term
        container["is_enabled"] = isEnabled
        container["created_at"] = createdAt
        container["updated_at"] = updatedAt
    }

    // MARK: - Mutations

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}
