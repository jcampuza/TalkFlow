import XCTest
@testable import TalkFlow

final class DictionaryStorageTests: XCTestCase {
    var storage: DictionaryStorage!
    var testDatabasePath: String!

    override func setUp() {
        super.setUp()
        // Create a test-specific database path
        let tempDir = FileManager.default.temporaryDirectory
        testDatabasePath = tempDir.appendingPathComponent("test_dictionary_\(UUID().uuidString).sqlite").path

        do {
            storage = try DictionaryStorage(databasePath: testDatabasePath)
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
        super.tearDown()
    }

    // MARK: - Basic CRUD Tests

    func testSaveAndFetch() async throws {
        let term = DictionaryTerm(term: "BLK")

        try await storage.save(term)

        let fetched = await storage.fetchAll()
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.term, "BLK")
        XCTAssertTrue(fetched.first?.isEnabled ?? false)
    }

    func testSaveMultipleTerms() async throws {
        try await storage.save(DictionaryTerm(term: "BLK"))
        try await storage.save(DictionaryTerm(term: "BPM"))
        try await storage.save(DictionaryTerm(term: "OTP"))

        let fetched = await storage.fetchAll()
        XCTAssertEqual(fetched.count, 3)
    }

    func testUpdateTerm() async throws {
        let term = DictionaryTerm(term: "BLK")
        try await storage.save(term)

        // Fetch the saved term (it now has an ID)
        let savedTerms = await storage.fetchAll()
        XCTAssertEqual(savedTerms.count, 1)
        var savedTerm = savedTerms.first!

        // Update the term
        savedTerm.term = "UPDATED"
        savedTerm.isEnabled = false
        try await storage.update(savedTerm)

        let updated = await storage.fetchAll()
        XCTAssertEqual(updated.count, 1)
        XCTAssertEqual(updated.first?.term, "UPDATED")
        XCTAssertFalse(updated.first?.isEnabled ?? true)
    }

    func testDeleteTerm() async throws {
        let term = DictionaryTerm(term: "ToDelete")
        try await storage.save(term)

        var fetched = await storage.fetchAll()
        XCTAssertEqual(fetched.count, 1)

        // Fetch saved term with ID
        let savedTerm = fetched.first!
        try await storage.delete(savedTerm)

        fetched = await storage.fetchAll()
        XCTAssertEqual(fetched.count, 0)
    }

    // MARK: - Enabled/Disabled Filter Tests

    func testFetchEnabled() async throws {
        let term1 = DictionaryTerm(term: "Enabled1", isEnabled: true)
        let term2 = DictionaryTerm(term: "Enabled2", isEnabled: true)
        let term3 = DictionaryTerm(term: "Disabled", isEnabled: false)

        try await storage.save(term1)
        try await storage.save(term2)
        try await storage.save(term3)

        let enabled = await storage.fetchEnabled()
        XCTAssertEqual(enabled.count, 2)
        XCTAssertTrue(enabled.allSatisfy { $0.isEnabled })
    }

    // MARK: - Duplicate Detection Tests

    func testTermExistsExactMatch() async throws {
        try await storage.save(DictionaryTerm(term: "BLK"))

        let existsBLK = await storage.termExists("BLK")
        let existsblk = await storage.termExists("blk")
        let existsOTHER = await storage.termExists("OTHER")

        XCTAssertTrue(existsBLK)
        XCTAssertFalse(existsblk) // Case sensitive
        XCTAssertFalse(existsOTHER)
    }

    func testDuplicateTermRejected() async throws {
        try await storage.save(DictionaryTerm(term: "BLK"))

        // Attempting to save a duplicate should throw
        do {
            try await storage.save(DictionaryTerm(term: "BLK"))
            XCTFail("Expected error for duplicate term")
        } catch {
            // Expected
        }
    }

    func testDifferentCaseAllowed() async throws {
        try await storage.save(DictionaryTerm(term: "BLK"))
        try await storage.save(DictionaryTerm(term: "blk"))
        try await storage.save(DictionaryTerm(term: "Blk"))

        let fetched = await storage.fetchAll()
        XCTAssertEqual(fetched.count, 3)
    }

    // MARK: - Count Tests

    func testCount() async throws {
        var count = await storage.count()
        XCTAssertEqual(count, 0)

        try await storage.save(DictionaryTerm(term: "Term1"))
        count = await storage.count()
        XCTAssertEqual(count, 1)

        try await storage.save(DictionaryTerm(term: "Term2"))
        count = await storage.count()
        XCTAssertEqual(count, 2)
    }

    // MARK: - Sort Order Tests

    func testNewestFirst() async throws {
        try await storage.save(DictionaryTerm(term: "First"))
        // Small delay to ensure different timestamps
        try await Task.sleep(for: .milliseconds(10))
        try await storage.save(DictionaryTerm(term: "Second"))
        try await Task.sleep(for: .milliseconds(10))
        try await storage.save(DictionaryTerm(term: "Third"))

        let terms = await storage.fetchAll()
        XCTAssertEqual(terms.count, 3)
        XCTAssertEqual(terms[0].term, "Third") // Most recent first
        XCTAssertEqual(terms[1].term, "Second")
        XCTAssertEqual(terms[2].term, "First")
    }

    // MARK: - Special Characters Tests

    func testSpecialCharacters() async throws {
        try await storage.save(DictionaryTerm(term: "next.js"))
        try await storage.save(DictionaryTerm(term: "react-native"))
        try await storage.save(DictionaryTerm(term: "C++"))
        try await storage.save(DictionaryTerm(term: "test term with spaces"))

        let terms = await storage.fetchAll()
        XCTAssertEqual(terms.count, 4)
    }
}
