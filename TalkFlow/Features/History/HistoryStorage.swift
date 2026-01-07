import Foundation
import GRDB
import Observation

/// Protocol for history storage operations, enabling testability
protocol HistoryStorageProtocol: AnyObject, Sendable {
    @MainActor var recentRecords: [TranscriptionRecord] { get }
    func save(_ record: TranscriptionRecord) async throws
    func delete(_ record: TranscriptionRecord) async throws
    func deleteAll() async throws
    func fetchAll() async -> [TranscriptionRecord]
    func fetchRecent(limit: Int) async -> [TranscriptionRecord]
    func search(query: String) async -> [TranscriptionRecord]
    func getRecord(id: String) async -> TranscriptionRecord?
}

@Observable
final class HistoryStorage: HistoryStorageProtocol, @unchecked Sendable {
    private var dbQueue: DatabaseQueue?

    @MainActor private(set) var recentRecords: [TranscriptionRecord] = []

    private let databaseURL: URL

    /// Default production initializer using Application Support directory
    init() {
        let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let talkFlowDir = appSupportURL.appendingPathComponent("TalkFlow", isDirectory: true)

        // Create directory if needed
        try? FileManager.default.createDirectory(at: talkFlowDir, withIntermediateDirectories: true)

        databaseURL = talkFlowDir.appendingPathComponent("transcriptions.sqlite")

        do {
            try setupDatabase()
            Task { @MainActor in
                await self.loadRecentRecords()
            }
            Logger.shared.info("History storage initialized at \(databaseURL.path)", component: "HistoryStorage")
        } catch {
            Logger.shared.error("Failed to initialize database: \(error)", component: "HistoryStorage")
        }
    }

    /// Initializer for testing with a custom database path
    /// Pass nil or ":memory:" for an in-memory database (useful for isolated tests)
    init(databasePath: String) throws {
        if databasePath == ":memory:" {
            // In-memory database for testing
            self.databaseURL = URL(fileURLWithPath: databasePath)
        } else {
            self.databaseURL = URL(fileURLWithPath: databasePath)

            // Ensure parent directory exists
            let parentDir = databaseURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true)
        }

        try setupDatabase()
        // For testing initializer, load synchronously
        let records = fetchRecentSync()
        Task { @MainActor in
            self.recentRecords = records
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

    func save(_ record: TranscriptionRecord) async throws {
        try await dbQueue?.write { db in
            try record.insert(db)
        }
        await loadRecentRecords()
        Logger.shared.debug("Saved transcription record: \(record.id)", component: "HistoryStorage")
    }

    func delete(_ record: TranscriptionRecord) async throws {
        _ = try await dbQueue?.write { db in
            try record.delete(db)
        }
        await loadRecentRecords()
        Logger.shared.debug("Deleted transcription record: \(record.id)", component: "HistoryStorage")
    }

    func deleteAll() async throws {
        _ = try await dbQueue?.write { db in
            try TranscriptionRecord.deleteAll(db)
        }
        await loadRecentRecords()
        Logger.shared.info("Deleted all transcription records", component: "HistoryStorage")
    }

    func fetchAll() async -> [TranscriptionRecord] {
        do {
            return try await dbQueue?.read { db in
                try TranscriptionRecord
                    .order(Column("timestamp").desc)
                    .fetchAll(db)
            } ?? []
        } catch {
            Logger.shared.error("Failed to fetch records: \(error)", component: "HistoryStorage")
            return []
        }
    }

    func fetchRecent(limit: Int = 5) async -> [TranscriptionRecord] {
        do {
            return try await dbQueue?.read { db in
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

    func search(query: String) async -> [TranscriptionRecord] {
        guard !query.isEmpty else { return await fetchAll() }

        do {
            return try await dbQueue?.read { db in
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
            let allRecords = await fetchAll()
            return allRecords.filter { $0.text.localizedCaseInsensitiveContains(query) }
        }
    }

    func getRecord(id: String) async -> TranscriptionRecord? {
        do {
            return try await dbQueue?.read { db in
                try TranscriptionRecord.fetchOne(db, key: id)
            }
        } catch {
            Logger.shared.error("Failed to fetch record: \(error)", component: "HistoryStorage")
            return nil
        }
    }

    @MainActor
    private func loadRecentRecords() async {
        recentRecords = await fetchRecent()
    }

    // Synchronous version for initialization
    private func fetchRecentSync(limit: Int = 5) -> [TranscriptionRecord] {
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
}
