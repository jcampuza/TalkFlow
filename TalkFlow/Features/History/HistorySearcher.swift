import Foundation

@Observable
final class HistorySearcher: @unchecked Sendable {
    @MainActor var searchText: String = "" {
        didSet {
            scheduleSearch()
        }
    }
    @MainActor private(set) var searchResults: [TranscriptionRecord] = []
    @MainActor private(set) var isSearching = false

    private var historyStorage: HistoryStorage?
    private var searchTask: Task<Void, Never>?

    init() {}

    init(historyStorage: HistoryStorage) {
        self.historyStorage = historyStorage
    }

    @MainActor
    func setStorage(_ storage: HistoryStorage) {
        self.historyStorage = storage
    }

    @MainActor
    private func scheduleSearch() {
        guard historyStorage != nil else { return }
        searchTask?.cancel()
        searchTask = Task { @MainActor in
            // Debounce
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            await performSearch(query: searchText)
        }
    }

    @MainActor
    private func performSearch(query: String) async {
        guard let historyStorage = historyStorage else { return }
        isSearching = true

        let results = await historyStorage.search(query: query)

        guard !Task.isCancelled else { return }
        searchResults = results
        isSearching = false
    }

    @MainActor
    func clearSearch() {
        searchText = ""
    }
}
