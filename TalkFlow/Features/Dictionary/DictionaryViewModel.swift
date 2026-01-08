import Foundation

/// ViewModel for the Dictionary UI that bridges the DictionaryManager to the view.
/// Centralizes UI state and action handling, making the view simpler and logic testable.
@Observable
@MainActor
final class DictionaryViewModel {
    // MARK: - Dependencies

    private let manager: DictionaryManager

    // MARK: - UI State

    var searchText: String = ""
    var errorMessage: String?
    var showingError = false

    // MARK: - Computed Properties (Easily unit-testable)

    /// Terms filtered by search query
    var filteredTerms: [DictionaryTerm] {
        manager.filterTerms(query: searchText)
    }

    /// Whether the dictionary has no terms at all
    var isEmpty: Bool {
        manager.terms.isEmpty
    }

    /// Whether search returned no results
    var hasNoSearchResults: Bool {
        !searchText.isEmpty && filteredTerms.isEmpty
    }

    /// Whether the dictionary is at its limit (50 terms)
    var isAtLimit: Bool {
        manager.isAtLimit
    }

    /// Display label for term count (e.g., "12/50")
    var termCountLabel: String {
        "\(manager.termCount)/50"
    }

    // MARK: - Initialization

    init(manager: DictionaryManager) {
        self.manager = manager
    }

    // MARK: - Actions

    func addTerm(_ text: String) {
        performAction {
            try await self.manager.addTerm(text)
        }
    }

    func updateTerm(_ term: DictionaryTerm, newText: String) {
        performAction {
            try await self.manager.updateTerm(term, newText: newText)
        }
    }

    func toggleTerm(_ term: DictionaryTerm) {
        performAction {
            try await self.manager.toggleTerm(term)
        }
    }

    func deleteTerm(_ term: DictionaryTerm) {
        performAction {
            try await self.manager.deleteTerm(term)
        }
    }

    func clearSearch() {
        searchText = ""
    }

    func dismissError() {
        showingError = false
        errorMessage = nil
    }

    // MARK: - Private Helpers

    /// Centralized action handler that wraps async operations with error handling
    private func performAction(_ action: @escaping () async throws -> Void) {
        Task {
            do {
                try await action()
            } catch {
                self.errorMessage = error.localizedDescription
                self.showingError = true
            }
        }
    }
}
