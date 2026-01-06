import Foundation
@testable import TalkFlow

final class MockDictionaryStorage: DictionaryStorageProtocol, @unchecked Sendable {
    private var _terms: [DictionaryTerm] = []

    @MainActor var terms: [DictionaryTerm] {
        _terms.sorted { $0.createdAt > $1.createdAt }
    }

    func save(_ term: DictionaryTerm) async throws {
        // Check for duplicate
        if _terms.contains(where: { $0.term == term.term }) {
            throw NSError(domain: "MockDictionaryStorage", code: 1, userInfo: [NSLocalizedDescriptionKey: "Duplicate term"])
        }

        var newTerm = term
        newTerm.id = Int64(_terms.count + 1)
        newTerm.createdAt = Date()
        newTerm.updatedAt = Date()
        _terms.append(newTerm)
    }

    func update(_ term: DictionaryTerm) async throws {
        guard let index = _terms.firstIndex(where: { $0.id == term.id }) else {
            throw NSError(domain: "MockDictionaryStorage", code: 2, userInfo: [NSLocalizedDescriptionKey: "Term not found"])
        }

        var updatedTerm = term
        updatedTerm.updatedAt = Date()
        _terms[index] = updatedTerm
    }

    func delete(_ term: DictionaryTerm) async throws {
        _terms.removeAll { $0.id == term.id }
    }

    func fetchAll() async -> [DictionaryTerm] {
        return _terms.sorted { $0.createdAt > $1.createdAt }
    }

    func fetchEnabled() async -> [DictionaryTerm] {
        return await fetchAll().filter { $0.isEnabled }
    }

    func termExists(_ termText: String) async -> Bool {
        return _terms.contains { $0.term == termText }
    }

    func count() async -> Int {
        return _terms.count
    }

    // Test helper methods
    func reset() {
        _terms.removeAll()
    }

    func addTermsDirectly(_ terms: [DictionaryTerm]) {
        for term in terms {
            var newTerm = term
            newTerm.id = Int64(_terms.count + 1)
            _terms.append(newTerm)
        }
    }
}
