import XCTest
@testable import TalkFlow

final class HistoryStorageTests: XCTestCase {
    var storage: HistoryStorage!

    override func setUp() {
        super.setUp()
        storage = HistoryStorage()
        // Clear all records for clean test
        storage.deleteAll()
    }

    override func tearDown() {
        storage.deleteAll()
        storage = nil
        super.tearDown()
    }

    func testSaveAndFetch() {
        let record = TranscriptionRecord(
            text: "Hello, world!",
            durationMs: 1000,
            confidence: 0.95
        )

        storage.save(record)

        let fetched = storage.fetchAll()
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.text, "Hello, world!")
    }

    func testDelete() {
        let record = TranscriptionRecord(text: "To be deleted")
        storage.save(record)

        XCTAssertEqual(storage.fetchAll().count, 1)

        storage.delete(record)
        XCTAssertEqual(storage.fetchAll().count, 0)
    }

    func testSearch() {
        storage.save(TranscriptionRecord(text: "The quick brown fox"))
        storage.save(TranscriptionRecord(text: "jumps over the lazy dog"))
        storage.save(TranscriptionRecord(text: "Hello world"))

        let foxResults = storage.search(query: "fox")
        XCTAssertEqual(foxResults.count, 1)
        XCTAssertTrue(foxResults.first?.text.contains("fox") ?? false)

        let theResults = storage.search(query: "the")
        XCTAssertEqual(theResults.count, 2)
    }

    func testFetchRecent() {
        for i in 0..<10 {
            storage.save(TranscriptionRecord(text: "Record \(i)"))
        }

        let recent = storage.fetchRecent(limit: 5)
        XCTAssertEqual(recent.count, 5)
    }

    func testDeleteAll() {
        storage.save(TranscriptionRecord(text: "Record 1"))
        storage.save(TranscriptionRecord(text: "Record 2"))
        storage.save(TranscriptionRecord(text: "Record 3"))

        XCTAssertEqual(storage.fetchAll().count, 3)

        storage.deleteAll()
        XCTAssertEqual(storage.fetchAll().count, 0)
    }
}
