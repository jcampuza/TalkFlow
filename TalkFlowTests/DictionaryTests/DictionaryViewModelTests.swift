import XCTest
@testable import TalkFlow

@MainActor
final class DictionaryViewModelTests: XCTestCase {
    var mockStorage: MockDictionaryStorage!
    var manager: DictionaryManager!
    var viewModel: DictionaryViewModel!

    override func setUp() async throws {
        try await super.setUp()
        mockStorage = MockDictionaryStorage()
        manager = DictionaryManager(storage: mockStorage)
        viewModel = DictionaryViewModel(manager: manager)
    }

    override func tearDown() async throws {
        mockStorage = nil
        manager = nil
        viewModel = nil
        try await super.tearDown()
    }

    // MARK: - Computed Properties Tests

    func testIsEmptyWhenNoTerms() {
        XCTAssertTrue(viewModel.isEmpty)
    }

    func testIsEmptyFalseWhenTermsExist() async throws {
        try await manager.addTerm("BLK")
        XCTAssertFalse(viewModel.isEmpty)
    }

    func testFilteredTermsReturnsAllWhenSearchEmpty() async throws {
        try await manager.addTerm("BLK")
        try await manager.addTerm("BPM")
        try await manager.addTerm("OTP")

        XCTAssertEqual(viewModel.filteredTerms.count, 3)
    }

    func testFilteredTermsFiltersOnSearch() async throws {
        try await manager.addTerm("next.js")
        try await manager.addTerm("react-native")
        try await manager.addTerm("kubectl")

        viewModel.searchText = "react"
        XCTAssertEqual(viewModel.filteredTerms.count, 1)
        XCTAssertEqual(viewModel.filteredTerms.first?.term, "react-native")
    }

    func testHasNoSearchResultsWhenSearchingWithNoMatches() async throws {
        try await manager.addTerm("BLK")

        XCTAssertFalse(viewModel.hasNoSearchResults) // Empty search = no results state

        viewModel.searchText = "xyz"
        XCTAssertTrue(viewModel.hasNoSearchResults)
    }

    func testHasNoSearchResultsFalseWhenSearchHasMatches() async throws {
        try await manager.addTerm("BLK")

        viewModel.searchText = "BLK"
        XCTAssertFalse(viewModel.hasNoSearchResults)
    }

    func testIsAtLimitFalseWhenUnderLimit() async throws {
        try await manager.addTerm("BLK")
        XCTAssertFalse(viewModel.isAtLimit)
    }

    func testIsAtLimitTrueAtLimit() async throws {
        for i in 0..<50 {
            try await manager.addTerm("Term\(i)")
        }
        XCTAssertTrue(viewModel.isAtLimit)
    }

    func testTermCountLabel() async throws {
        XCTAssertEqual(viewModel.termCountLabel, "0/50")

        try await manager.addTerm("BLK")
        XCTAssertEqual(viewModel.termCountLabel, "1/50")

        try await manager.addTerm("BPM")
        XCTAssertEqual(viewModel.termCountLabel, "2/50")
    }

    // MARK: - Action Tests

    func testAddTermAddsToManager() async throws {
        viewModel.addTerm("BLK")

        // Wait for async action to complete
        try await Task.sleep(for: .milliseconds(50))

        XCTAssertEqual(manager.termCount, 1)
        XCTAssertEqual(manager.terms.first?.term, "BLK")
    }

    func testAddTermShowsErrorOnFailure() async throws {
        // Add term first
        try await manager.addTerm("BLK")

        // Try to add duplicate via viewModel
        viewModel.addTerm("BLK")

        // Wait for async action to complete
        try await Task.sleep(for: .milliseconds(50))

        XCTAssertTrue(viewModel.showingError)
        XCTAssertNotNil(viewModel.errorMessage)
    }

    func testUpdateTermUpdatesInManager() async throws {
        try await manager.addTerm("BLK")
        let term = manager.terms.first!

        viewModel.updateTerm(term, newText: "UPDATED")

        // Wait for async action to complete
        try await Task.sleep(for: .milliseconds(50))

        XCTAssertEqual(manager.terms.first?.term, "UPDATED")
    }

    func testToggleTermTogglesInManager() async throws {
        try await manager.addTerm("BLK")
        let term = manager.terms.first!
        XCTAssertTrue(term.isEnabled)

        viewModel.toggleTerm(term)

        // Wait for async action to complete
        try await Task.sleep(for: .milliseconds(50))

        XCTAssertFalse(manager.terms.first?.isEnabled ?? true)
    }

    func testDeleteTermRemovesFromManager() async throws {
        try await manager.addTerm("BLK")
        let term = manager.terms.first!

        viewModel.deleteTerm(term)

        // Wait for async action to complete
        try await Task.sleep(for: .milliseconds(50))

        XCTAssertEqual(manager.termCount, 0)
    }

    func testClearSearchResetsSearchText() {
        viewModel.searchText = "test"
        XCTAssertEqual(viewModel.searchText, "test")

        viewModel.clearSearch()
        XCTAssertEqual(viewModel.searchText, "")
    }

    func testDismissErrorClearsErrorState() {
        viewModel.errorMessage = "Test error"
        viewModel.showingError = true

        viewModel.dismissError()

        XCTAssertFalse(viewModel.showingError)
        XCTAssertNil(viewModel.errorMessage)
    }

    // MARK: - Error Handling Tests

    func testAddEmptyTermShowsError() async throws {
        viewModel.addTerm("")

        // Wait for async action to complete
        try await Task.sleep(for: .milliseconds(50))

        XCTAssertTrue(viewModel.showingError)
        XCTAssertNotNil(viewModel.errorMessage)
    }

    func testAddTermBeyondLimitShowsError() async throws {
        // Add 50 terms via manager
        for i in 0..<50 {
            try await manager.addTerm("Term\(i)")
        }

        // Try to add 51st via viewModel
        viewModel.addTerm("Term50")

        // Wait for async action to complete
        try await Task.sleep(for: .milliseconds(50))

        XCTAssertTrue(viewModel.showingError)
        XCTAssertNotNil(viewModel.errorMessage)
    }
}
