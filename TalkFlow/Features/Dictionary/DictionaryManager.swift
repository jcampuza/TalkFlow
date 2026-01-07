import Foundation
import Observation

/// Errors that can occur when managing dictionary terms
enum DictionaryError: LocalizedError, Equatable, Sendable {
    case emptyTerm
    case duplicateTerm
    case limitReached
    case storageError(String)

    var errorDescription: String? {
        switch self {
        case .emptyTerm:
            return "Term cannot be empty"
        case .duplicateTerm:
            return "This term already exists"
        case .limitReached:
            return "Dictionary limit reached (50 terms). Delete some terms to add new ones."
        case .storageError(let message):
            return "Storage error: \(message)"
        }
    }
}

/// Manages dictionary terms with validation and business logic
@Observable
final class DictionaryManager: @unchecked Sendable {
    /// Maximum number of terms allowed in the dictionary
    static let maxTerms = 50

    private let storage: DictionaryStorageProtocol

    @MainActor private(set) var terms: [DictionaryTerm] = []
    @MainActor private(set) var enabledTerms: [String] = []

    init(storage: DictionaryStorageProtocol) {
        self.storage = storage

        // Initial load from storage
        Task { @MainActor in
            await self.refreshTerms()
        }
    }

    /// Refresh terms from storage
    @MainActor
    func refreshTerms() async {
        terms = storage.terms
        enabledTerms = terms.filter { $0.isEnabled }.map { $0.term }
        let enabledCount = terms.filter { $0.isEnabled }.count
        Logger.shared.debug("Dictionary: Applying \(enabledCount) enabled terms to prompt", component: "DictionaryManager")
    }

    /// Adds a new term to the dictionary
    /// - Parameter termText: The term to add (will be trimmed)
    /// - Throws: DictionaryError if validation fails or storage fails
    func addTerm(_ termText: String) async throws {
        let trimmedTerm = termText.trimmingCharacters(in: .whitespacesAndNewlines)

        // Validate empty
        guard !trimmedTerm.isEmpty else {
            throw DictionaryError.emptyTerm
        }

        // Check limit
        guard await storage.count() < Self.maxTerms else {
            throw DictionaryError.limitReached
        }

        // Check for duplicate (exact match)
        guard await !storage.termExists(trimmedTerm) else {
            throw DictionaryError.duplicateTerm
        }

        let term = DictionaryTerm(term: trimmedTerm)
        do {
            try await storage.save(term)
            await refreshTerms()
        } catch {
            throw DictionaryError.storageError(error.localizedDescription)
        }
    }

    /// Updates an existing term's text
    /// - Parameters:
    ///   - term: The term to update
    ///   - newText: The new term text
    /// - Throws: DictionaryError if validation fails or storage fails
    func updateTerm(_ term: DictionaryTerm, newText: String) async throws {
        let trimmedText = newText.trimmingCharacters(in: .whitespacesAndNewlines)

        // Validate empty
        guard !trimmedText.isEmpty else {
            throw DictionaryError.emptyTerm
        }

        // Check for duplicate (if term text changed)
        if trimmedText != term.term {
            let exists = await storage.termExists(trimmedText)
            if exists {
                throw DictionaryError.duplicateTerm
            }
        }

        var updatedTerm = term
        updatedTerm.term = trimmedText

        do {
            try await storage.update(updatedTerm)
            await refreshTerms()
        } catch {
            throw DictionaryError.storageError(error.localizedDescription)
        }
    }

    /// Toggles a term's enabled state
    /// - Parameter term: The term to toggle
    /// - Throws: DictionaryError if storage fails
    func toggleTerm(_ term: DictionaryTerm) async throws {
        var updatedTerm = term
        updatedTerm.isEnabled.toggle()

        do {
            try await storage.update(updatedTerm)
            await refreshTerms()
            Logger.shared.info("Dictionary: Toggled term '\(term.term)' to \(updatedTerm.isEnabled ? "enabled" : "disabled")", component: "DictionaryManager")
        } catch {
            throw DictionaryError.storageError(error.localizedDescription)
        }
    }

    /// Deletes a term from the dictionary
    /// - Parameter term: The term to delete
    /// - Throws: DictionaryError if storage fails
    func deleteTerm(_ term: DictionaryTerm) async throws {
        do {
            try await storage.delete(term)
            await refreshTerms()
        } catch {
            throw DictionaryError.storageError(error.localizedDescription)
        }
    }

    /// Filters terms by search query (case-insensitive)
    /// - Parameter query: The search query
    /// - Returns: Filtered list of terms
    @MainActor
    func filterTerms(query: String) -> [DictionaryTerm] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedQuery.isEmpty else {
            return terms
        }

        return terms.filter { $0.term.localizedCaseInsensitiveContains(trimmedQuery) }
    }

    /// Builds the prompt string for Whisper API
    /// - Returns: The prompt string containing enabled terms, or empty string if no terms
    @MainActor
    func buildPrompt() -> String {
        guard !enabledTerms.isEmpty else { return "" }
        let prompt = "Common terms: \(enabledTerms.joined(separator: ", "))"
        Logger.shared.debug("Dictionary: Built prompt with \(enabledTerms.count) terms", component: "DictionaryManager")
        return prompt
    }

    /// Returns whether the dictionary is at its limit
    @MainActor
    var isAtLimit: Bool {
        terms.count >= Self.maxTerms
    }

    /// Returns the current term count
    @MainActor
    var termCount: Int {
        terms.count
    }
}
