import XCTest
@testable import TalkFlow

@MainActor
final class DictionaryManagerTests: XCTestCase {
    var mockStorage: MockDictionaryStorage!
    var manager: DictionaryManager!

    override func setUp() async throws {
        try await super.setUp()
        mockStorage = MockDictionaryStorage()
        manager = DictionaryManager(storage: mockStorage)
    }

    override func tearDown() async throws {
        mockStorage = nil
        manager = nil
        try await super.tearDown()
    }

    // MARK: - Add Term Tests

    func testAddTermSuccessfully() async throws {
        try await manager.addTerm("BLK")

        let count = await mockStorage.count()
        XCTAssertEqual(count, 1)
        let terms = await mockStorage.fetchAll()
        XCTAssertEqual(terms.first?.term, "BLK")
    }

    func testAddTermTrimsWhitespace() async throws {
        try await manager.addTerm("  BLK  ")

        let terms = await mockStorage.fetchAll()
        XCTAssertEqual(terms.first?.term, "BLK")
    }

    func testAddEmptyTermThrows() async {
        do {
            try await manager.addTerm("")
            XCTFail("Expected emptyTerm error")
        } catch let error as DictionaryError {
            XCTAssertEqual(error, .emptyTerm)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testAddWhitespaceOnlyTermThrows() async {
        do {
            try await manager.addTerm("   ")
            XCTFail("Expected emptyTerm error")
        } catch let error as DictionaryError {
            XCTAssertEqual(error, .emptyTerm)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testAddDuplicateTermThrows() async throws {
        try await manager.addTerm("BLK")

        do {
            try await manager.addTerm("BLK")
            XCTFail("Expected duplicateTerm error")
        } catch let error as DictionaryError {
            XCTAssertEqual(error, .duplicateTerm)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testAddDifferentCaseAllowed() async throws {
        try await manager.addTerm("BLK")
        try await manager.addTerm("blk")

        let count = await mockStorage.count()
        XCTAssertEqual(count, 2)
    }

    func testAddTermAtLimit() async throws {
        // Add 49 terms
        for i in 0..<49 {
            try await manager.addTerm("Term\(i)")
        }

        var count = await mockStorage.count()
        XCTAssertEqual(count, 49)
        var isAtLimit = manager.isAtLimit
        XCTAssertFalse(isAtLimit)

        // Add 50th term should succeed
        try await manager.addTerm("Term49")
        count = await mockStorage.count()
        XCTAssertEqual(count, 50)
        isAtLimit = manager.isAtLimit
        XCTAssertTrue(isAtLimit)
    }

    func testAddTermBeyondLimitThrows() async throws {
        // Add 50 terms
        for i in 0..<50 {
            try await manager.addTerm("Term\(i)")
        }

        do {
            try await manager.addTerm("Term50")
            XCTFail("Expected limitReached error")
        } catch let error as DictionaryError {
            XCTAssertEqual(error, .limitReached)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    // MARK: - Update Term Tests

    func testUpdateTerm() async throws {
        try await manager.addTerm("BLK")

        let terms = await mockStorage.fetchAll()
        let term = terms.first!
        try await manager.updateTerm(term, newText: "UPDATED")

        let updatedTerms = await mockStorage.fetchAll()
        XCTAssertEqual(updatedTerms.first?.term, "UPDATED")
    }

    func testUpdateTermTrimsWhitespace() async throws {
        try await manager.addTerm("BLK")

        let terms = await mockStorage.fetchAll()
        let term = terms.first!
        try await manager.updateTerm(term, newText: "  UPDATED  ")

        let updatedTerms = await mockStorage.fetchAll()
        XCTAssertEqual(updatedTerms.first?.term, "UPDATED")
    }

    func testUpdateToEmptyTermThrows() async throws {
        try await manager.addTerm("BLK")

        let terms = await mockStorage.fetchAll()
        let term = terms.first!

        do {
            try await manager.updateTerm(term, newText: "")
            XCTFail("Expected emptyTerm error")
        } catch let error as DictionaryError {
            XCTAssertEqual(error, .emptyTerm)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testUpdateToDuplicateThrows() async throws {
        try await manager.addTerm("BLK")
        try await manager.addTerm("BPM")

        let terms = await mockStorage.fetchAll()
        let term = terms.first { $0.term == "BPM" }!

        do {
            try await manager.updateTerm(term, newText: "BLK")
            XCTFail("Expected duplicateTerm error")
        } catch let error as DictionaryError {
            XCTAssertEqual(error, .duplicateTerm)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testUpdateToSameTextAllowed() async throws {
        try await manager.addTerm("BLK")

        let terms = await mockStorage.fetchAll()
        let term = terms.first!
        // Updating to the same text (no change) should not throw
        try await manager.updateTerm(term, newText: "BLK")

        let updatedTerms = await mockStorage.fetchAll()
        XCTAssertEqual(updatedTerms.first?.term, "BLK")
    }

    // MARK: - Toggle Term Tests

    func testToggleTerm() async throws {
        try await manager.addTerm("BLK")

        var terms = await mockStorage.fetchAll()
        let term = terms.first!
        XCTAssertTrue(term.isEnabled)

        try await manager.toggleTerm(term)

        terms = await mockStorage.fetchAll()
        let updatedTerm = terms.first!
        XCTAssertFalse(updatedTerm.isEnabled)

        try await manager.toggleTerm(updatedTerm)

        terms = await mockStorage.fetchAll()
        let toggledAgain = terms.first!
        XCTAssertTrue(toggledAgain.isEnabled)
    }

    // MARK: - Delete Term Tests

    func testDeleteTerm() async throws {
        try await manager.addTerm("BLK")
        var count = await mockStorage.count()
        XCTAssertEqual(count, 1)

        let terms = await mockStorage.fetchAll()
        let term = terms.first!
        try await manager.deleteTerm(term)

        count = await mockStorage.count()
        XCTAssertEqual(count, 0)
    }

    // MARK: - Filter Terms Tests

    func testFilterTerms() async throws {
        try await manager.addTerm("next.js")
        try await manager.addTerm("react-native")
        try await manager.addTerm("BLK")
        try await manager.addTerm("kubectl")

        // Refresh terms in manager
        await manager.refreshTerms()

        let reactResults = manager.filterTerms(query: "react")
        XCTAssertEqual(reactResults.count, 1)
        XCTAssertEqual(reactResults.first?.term, "react-native")

        let emptyQuery = manager.filterTerms(query: "")
        XCTAssertEqual(emptyQuery.count, 4)

        let noResults = manager.filterTerms(query: "xyz")
        XCTAssertEqual(noResults.count, 0)
    }

    func testFilterTermsCaseInsensitive() async throws {
        try await manager.addTerm("BLK")

        // Refresh terms in manager
        await manager.refreshTerms()

        let results = manager.filterTerms(query: "blk")
        XCTAssertEqual(results.count, 1)
    }

    // MARK: - Build Prompt Tests

    func testBuildPromptEmpty() async {
        let prompt = manager.buildPrompt()
        XCTAssertEqual(prompt, "")
    }

    func testBuildPromptWithTerms() async throws {
        try await manager.addTerm("BLK")
        try await manager.addTerm("BPM")
        try await manager.addTerm("OTP")

        // Refresh terms in manager
        await manager.refreshTerms()

        let prompt = manager.buildPrompt()
        XCTAssertTrue(prompt.starts(with: "Common terms:"))
        XCTAssertTrue(prompt.contains("BLK"))
        XCTAssertTrue(prompt.contains("BPM"))
        XCTAssertTrue(prompt.contains("OTP"))
    }

    func testBuildPromptExcludesDisabled() async throws {
        try await manager.addTerm("BLK")
        try await manager.addTerm("BPM")

        // Disable one term
        let terms = await mockStorage.fetchAll()
        let term = terms.first { $0.term == "BPM" }!
        try await manager.toggleTerm(term)

        // Refresh terms in manager
        await manager.refreshTerms()

        let prompt = manager.buildPrompt()
        XCTAssertTrue(prompt.contains("BLK"))
        XCTAssertFalse(prompt.contains("BPM"))
    }

    // MARK: - Limit Properties Tests

    func testIsAtLimit() async throws {
        XCTAssertFalse(manager.isAtLimit)

        for i in 0..<50 {
            try await manager.addTerm("Term\(i)")
        }

        // Refresh to update cached terms
        await manager.refreshTerms()
        XCTAssertTrue(manager.isAtLimit)
    }

    func testTermCount() async throws {
        XCTAssertEqual(manager.termCount, 0)

        try await manager.addTerm("BLK")
        await manager.refreshTerms()
        XCTAssertEqual(manager.termCount, 1)

        try await manager.addTerm("BPM")
        await manager.refreshTerms()
        XCTAssertEqual(manager.termCount, 2)
    }
}
