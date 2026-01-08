import XCTest
@testable import TalkFlow

final class HistoryStorageTests: XCTestCase {
    var storage: HistoryStorage!
    var testDatabasePath: String!

    override func setUp() {
        super.setUp()
        // Create a test-specific database path for isolation
        let tempDir = FileManager.default.temporaryDirectory
        testDatabasePath = tempDir.appendingPathComponent("test_history_\(UUID().uuidString).sqlite").path

        do {
            storage = try HistoryStorage(databasePath: testDatabasePath)
        } catch {
            XCTFail("Failed to create test storage: \(error)")
        }
    }

    override func tearDown() {
        // Clean up test database
        if let path = testDatabasePath {
            try? FileManager.default.removeItem(atPath: path)
        }
        storage = nil
        testDatabasePath = nil
        super.tearDown()
    }

    func testSaveAndFetch() async throws {
        let record = TranscriptionRecord(
            text: "Hello, world!",
            durationMs: 1000,
            confidence: 0.95
        )

        try await storage.save(record)

        let fetched = await storage.fetchAll()
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.text, "Hello, world!")
    }

    func testDelete() async throws {
        let record = TranscriptionRecord(text: "To be deleted")
        try await storage.save(record)

        var fetched = await storage.fetchAll()
        XCTAssertEqual(fetched.count, 1)

        try await storage.delete(record)
        fetched = await storage.fetchAll()
        XCTAssertEqual(fetched.count, 0)
    }

    func testSearch() async throws {
        try await storage.save(TranscriptionRecord(text: "The quick brown fox"))
        try await storage.save(TranscriptionRecord(text: "jumps over the lazy dog"))
        try await storage.save(TranscriptionRecord(text: "Hello world"))

        let foxResults = await storage.search(query: "fox")
        XCTAssertEqual(foxResults.count, 1)
        XCTAssertTrue(foxResults.first?.text.contains("fox") ?? false)

        let theResults = await storage.search(query: "the")
        XCTAssertEqual(theResults.count, 2)
    }

    func testFetchRecent() async throws {
        for i in 0..<10 {
            try await storage.save(TranscriptionRecord(text: "Record \(i)"))
        }

        let recent = await storage.fetchRecent(limit: 5)
        XCTAssertEqual(recent.count, 5)
    }

    func testDeleteAll() async throws {
        try await storage.save(TranscriptionRecord(text: "Record 1"))
        try await storage.save(TranscriptionRecord(text: "Record 2"))
        try await storage.save(TranscriptionRecord(text: "Record 3"))

        var fetched = await storage.fetchAll()
        XCTAssertEqual(fetched.count, 3)

        try await storage.deleteAll()
        fetched = await storage.fetchAll()
        XCTAssertEqual(fetched.count, 0)
    }

    func testSaveEmptyRecordSkipped() async throws {
        try await storage.save(TranscriptionRecord(text: ""))

        let fetched = await storage.fetchAll()
        XCTAssertEqual(fetched.count, 0, "Empty records should not be saved")
    }

    func testSaveWhitespaceOnlyRecordSkipped() async throws {
        try await storage.save(TranscriptionRecord(text: "   "))
        try await storage.save(TranscriptionRecord(text: "\n\t"))

        let fetched = await storage.fetchAll()
        XCTAssertEqual(fetched.count, 0, "Whitespace-only records should not be saved")
    }
}
