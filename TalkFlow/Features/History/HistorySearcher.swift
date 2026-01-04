import Foundation
import Combine

final class HistorySearcher: ObservableObject {
    @Published var searchText: String = ""
    @Published private(set) var searchResults: [TranscriptionRecord] = []
    @Published private(set) var isSearching = false

    private let historyStorage: HistoryStorage
    private var searchCancellable: AnyCancellable?

    init(historyStorage: HistoryStorage) {
        self.historyStorage = historyStorage

        // Debounce search input
        searchCancellable = $searchText
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .removeDuplicates()
            .sink { [weak self] query in
                self?.performSearch(query: query)
            }
    }

    private func performSearch(query: String) {
        isSearching = true

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let results = self?.historyStorage.search(query: query) ?? []

            DispatchQueue.main.async {
                self?.searchResults = results
                self?.isSearching = false
            }
        }
    }

    func clearSearch() {
        searchText = ""
    }
}
