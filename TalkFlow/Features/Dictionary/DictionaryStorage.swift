import Foundation
import GRDB

/// Protocol for dictionary storage operations, enabling testability
protocol DictionaryStorageProtocol: AnyObject, Sendable {
    @MainActor var terms: [DictionaryTerm] { get }

    func save(_ term: DictionaryTerm) async throws
    func update(_ term: DictionaryTerm) async throws
    func delete(_ term: DictionaryTerm) async throws
    func fetchAll() async -> [DictionaryTerm]
    func fetchEnabled() async -> [DictionaryTerm]
    func termExists(_ termText: String) async -> Bool
    func count() async -> Int
}

@Observable
final class DictionaryStorage: DictionaryStorageProtocol, @unchecked Sendable {
    private var dbQueue: DatabaseQueue?

    @MainActor private(set) var terms: [DictionaryTerm] = []

    private let databaseURL: URL

    init() {
        let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let talkFlowDir = appSupportURL.appendingPathComponent("TalkFlow", isDirectory: true)

        // Create directory if needed
        try? FileManager.default.createDirectory(at: talkFlowDir, withIntermediateDirectories: true)

        databaseURL = talkFlowDir.appendingPathComponent("transcriptions.sqlite")

        do {
            try setupDatabase()
            Task { @MainActor in
                await self.loadTerms()
            }
            Logger.shared.info("Dictionary storage initialized", component: "DictionaryStorage")
        } catch {
            Logger.shared.error("Failed to initialize dictionary database: \(error)", component: "DictionaryStorage")
        }
    }

    /// Initializer for testing with a custom database path
    init(databasePath: String) throws {
        databaseURL = URL(fileURLWithPath: databasePath)

        // Ensure parent directory exists
        let parentDir = databaseURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true)

        try setupDatabase()
        // For testing, load synchronously
        let fetchedTerms = fetchAllSync()
        Task { @MainActor in
            self.terms = fetchedTerms
        }
    }

    private func setupDatabase() throws {
        dbQueue = try DatabaseQueue(path: databaseURL.path)

        try dbQueue?.write { db in
            // Create dictionary_terms table
            try db.create(table: "dictionary_terms", ifNotExists: true) { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("term", .text).notNull()
                t.column("is_enabled", .integer).notNull().defaults(to: true)
                t.column("created_at", .datetime).notNull()
                t.column("updated_at", .datetime).notNull()
            }

            // Create unique index on term (case-sensitive)
            try db.execute(sql: "CREATE UNIQUE INDEX IF NOT EXISTS idx_dictionary_term ON dictionary_terms(term)")
        }

        Logger.shared.debug("Dictionary database schema initialized", component: "DictionaryStorage")
    }

    func save(_ term: DictionaryTerm) async throws {
        var termToSave = term
        termToSave.createdAt = Date()
        termToSave.updatedAt = Date()
        let finalTerm = termToSave  // Create immutable copy for Sendable capture

        do {
            try await dbQueue?.write { db in
                try finalTerm.insert(db)
            }
            await loadTerms()
            Logger.shared.info("Dictionary: Added term '\(term.term)'", component: "DictionaryStorage")
        } catch {
            Logger.shared.error("Failed to save term: \(error)", component: "DictionaryStorage")
            throw error
        }
    }

    func update(_ term: DictionaryTerm) async throws {
        var termToUpdate = term
        termToUpdate.updatedAt = Date()
        let finalTerm = termToUpdate  // Create immutable copy for Sendable capture

        do {
            try await dbQueue?.write { db in
                try finalTerm.update(db)
            }
            await loadTerms()
            Logger.shared.info("Dictionary: Updated term '\(term.term)'", component: "DictionaryStorage")
        } catch {
            Logger.shared.error("Failed to update term: \(error)", component: "DictionaryStorage")
            throw error
        }
    }

    func delete(_ term: DictionaryTerm) async throws {
        do {
            _ = try await dbQueue?.write { db in
                try term.delete(db)
            }
            await loadTerms()
            Logger.shared.info("Dictionary: Removed term '\(term.term)'", component: "DictionaryStorage")
        } catch {
            Logger.shared.error("Failed to delete term: \(error)", component: "DictionaryStorage")
            throw error
        }
    }

    func fetchAll() async -> [DictionaryTerm] {
        do {
            return try await dbQueue?.read { db in
                try DictionaryTerm
                    .order(Column("created_at").desc)
                    .fetchAll(db)
            } ?? []
        } catch {
            Logger.shared.error("Failed to fetch terms: \(error)", component: "DictionaryStorage")
            return []
        }
    }

    func fetchEnabled() async -> [DictionaryTerm] {
        do {
            return try await dbQueue?.read { db in
                try DictionaryTerm
                    .filter(Column("is_enabled") == true)
                    .order(Column("created_at").desc)
                    .fetchAll(db)
            } ?? []
        } catch {
            Logger.shared.error("Failed to fetch enabled terms: \(error)", component: "DictionaryStorage")
            return []
        }
    }

    func termExists(_ termText: String) async -> Bool {
        do {
            return try await dbQueue?.read { db in
                try DictionaryTerm
                    .filter(Column("term") == termText)
                    .fetchCount(db) > 0
            } ?? false
        } catch {
            Logger.shared.error("Failed to check term existence: \(error)", component: "DictionaryStorage")
            return false
        }
    }

    func count() async -> Int {
        do {
            return try await dbQueue?.read { db in
                try DictionaryTerm.fetchCount(db)
            } ?? 0
        } catch {
            Logger.shared.error("Failed to count terms: \(error)", component: "DictionaryStorage")
            return 0
        }
    }

    @MainActor
    private func loadTerms() async {
        terms = await fetchAll()
        Logger.shared.debug("Dictionary: Loaded \(terms.count) terms", component: "DictionaryStorage")
    }

    // Synchronous version for initialization
    private func fetchAllSync() -> [DictionaryTerm] {
        do {
            return try dbQueue?.read { db in
                try DictionaryTerm
                    .order(Column("created_at").desc)
                    .fetchAll(db)
            } ?? []
        } catch {
            Logger.shared.error("Failed to fetch terms: \(error)", component: "DictionaryStorage")
            return []
        }
    }
}
