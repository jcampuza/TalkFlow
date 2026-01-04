import Foundation
import GRDB
import Combine

final class HistoryStorage: ObservableObject {
    private var dbQueue: DatabaseQueue?

    @Published private(set) var recentRecords: [TranscriptionRecord] = []

    private let databaseURL: URL

    init() {
        let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let talkFlowDir = appSupportURL.appendingPathComponent("TalkFlow", isDirectory: true)

        // Create directory if needed
        try? FileManager.default.createDirectory(at: talkFlowDir, withIntermediateDirectories: true)

        databaseURL = talkFlowDir.appendingPathComponent("transcriptions.sqlite")

        do {
            try setupDatabase()
            loadRecentRecords()
            Logger.shared.info("History storage initialized at \(databaseURL.path)", component: "HistoryStorage")
        } catch {
            Logger.shared.error("Failed to initialize database: \(error)", component: "HistoryStorage")
        }
    }

    private func setupDatabase() throws {
        dbQueue = try DatabaseQueue(path: databaseURL.path)

        try dbQueue?.write { db in
            // Create main table
            try db.create(table: "transcriptions", ifNotExists: true) { t in
                t.column("id", .text).primaryKey()
                t.column("text", .text).notNull()
                t.column("timestamp", .datetime).notNull()
                t.column("duration_ms", .integer)
                t.column("confidence", .double)
                t.column("created_at", .datetime).defaults(to: Date())
            }

            // Create FTS table for full-text search
            try db.execute(sql: """
                CREATE VIRTUAL TABLE IF NOT EXISTS transcriptions_fts
                USING fts5(text, content='transcriptions', content_rowid='rowid')
            """)

            // Create triggers to keep FTS in sync
            try db.execute(sql: """
                CREATE TRIGGER IF NOT EXISTS transcriptions_ai AFTER INSERT ON transcriptions BEGIN
                    INSERT INTO transcriptions_fts(rowid, text) VALUES (new.rowid, new.text);
                END
            """)

            try db.execute(sql: """
                CREATE TRIGGER IF NOT EXISTS transcriptions_ad AFTER DELETE ON transcriptions BEGIN
                    INSERT INTO transcriptions_fts(transcriptions_fts, rowid, text) VALUES('delete', old.rowid, old.text);
                END
            """)

            try db.execute(sql: """
                CREATE TRIGGER IF NOT EXISTS transcriptions_au AFTER UPDATE ON transcriptions BEGIN
                    INSERT INTO transcriptions_fts(transcriptions_fts, rowid, text) VALUES('delete', old.rowid, old.text);
                    INSERT INTO transcriptions_fts(rowid, text) VALUES (new.rowid, new.text);
                END
            """)
        }
    }

    func save(_ record: TranscriptionRecord) {
        do {
            try dbQueue?.write { db in
                try record.insert(db)
            }
            loadRecentRecords()
            Logger.shared.debug("Saved transcription record: \(record.id)", component: "HistoryStorage")
        } catch {
            Logger.shared.error("Failed to save record: \(error)", component: "HistoryStorage")
        }
    }

    func delete(_ record: TranscriptionRecord) {
        do {
            try dbQueue?.write { db in
                try record.delete(db)
            }
            loadRecentRecords()
            Logger.shared.debug("Deleted transcription record: \(record.id)", component: "HistoryStorage")
        } catch {
            Logger.shared.error("Failed to delete record: \(error)", component: "HistoryStorage")
        }
    }

    func deleteAll() {
        do {
            try dbQueue?.write { db in
                try TranscriptionRecord.deleteAll(db)
            }
            loadRecentRecords()
            Logger.shared.info("Deleted all transcription records", component: "HistoryStorage")
        } catch {
            Logger.shared.error("Failed to delete all records: \(error)", component: "HistoryStorage")
        }
    }

    func fetchAll() -> [TranscriptionRecord] {
        do {
            return try dbQueue?.read { db in
                try TranscriptionRecord
                    .order(Column("timestamp").desc)
                    .fetchAll(db)
            } ?? []
        } catch {
            Logger.shared.error("Failed to fetch records: \(error)", component: "HistoryStorage")
            return []
        }
    }

    func fetchRecent(limit: Int = 5) -> [TranscriptionRecord] {
        do {
            return try dbQueue?.read { db in
                try TranscriptionRecord
                    .order(Column("timestamp").desc)
                    .limit(limit)
                    .fetchAll(db)
            } ?? []
        } catch {
            Logger.shared.error("Failed to fetch recent records: \(error)", component: "HistoryStorage")
            return []
        }
    }

    func search(query: String) -> [TranscriptionRecord] {
        guard !query.isEmpty else { return fetchAll() }

        do {
            return try dbQueue?.read { db in
                // Use FTS5 for full-text search
                let pattern = query
                    .split(separator: " ")
                    .map { "\($0)*" }
                    .joined(separator: " ")

                return try TranscriptionRecord.matching(pattern).fetchAll(db)
            } ?? []
        } catch {
            Logger.shared.error("Search failed: \(error)", component: "HistoryStorage")
            // Fallback to simple LIKE search
            return fetchAll().filter { $0.text.localizedCaseInsensitiveContains(query) }
        }
    }

    func getRecord(id: String) -> TranscriptionRecord? {
        do {
            return try dbQueue?.read { db in
                try TranscriptionRecord.fetchOne(db, key: id)
            }
        } catch {
            Logger.shared.error("Failed to fetch record: \(error)", component: "HistoryStorage")
            return nil
        }
    }

    private func loadRecentRecords() {
        DispatchQueue.main.async { [weak self] in
            self?.recentRecords = self?.fetchRecent() ?? []
        }
    }
}
