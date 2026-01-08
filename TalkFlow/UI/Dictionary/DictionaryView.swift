import SwiftUI

struct DictionaryView: View {
    // Initialize ViewModel in init to avoid flicker
    @State private var viewModel: DictionaryViewModel

    init(manager: DictionaryManager) {
        _viewModel = State(initialValue: DictionaryViewModel(manager: manager))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Add term input
            AddTermView(isAtLimit: viewModel.isAtLimit) { term in
                viewModel.addTerm(term)
            }

            Rectangle()
                .fill(DesignConstants.dividerColor)
                .frame(height: 1)

            // Search bar (only shown when there are terms)
            if !viewModel.isEmpty {
                searchBar

                Rectangle()
                    .fill(DesignConstants.dividerColor)
                    .frame(height: 1)
            }

            // Content: list, empty state, or no results
            if viewModel.isEmpty {
                emptyStateView
            } else if viewModel.hasNoSearchResults {
                noResultsView
            } else {
                termsList
            }
        }
        .background(Color.white)
        .frame(minWidth: 400, minHeight: 300)
        .alert("Error", isPresented: $viewModel.showingError) {
            Button("OK", role: .cancel) {
                viewModel.dismissError()
            }
        } message: {
            Text(viewModel.errorMessage ?? "An unknown error occurred")
        }
    }

    // MARK: - Subviews

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(DesignConstants.secondaryText)

            TextField("Filter terms...", text: $viewModel.searchText)
                .textFieldStyle(.plain)
                .foregroundColor(DesignConstants.primaryText)

            if !viewModel.searchText.isEmpty {
                Button(action: { viewModel.clearSearch() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(DesignConstants.secondaryText)
                }
                .buttonStyle(.plain)
            }

            Text(viewModel.termCountLabel)
                .font(.caption)
                .foregroundColor(DesignConstants.secondaryText)
        }
        .padding(12)
        .background(DesignConstants.searchBarBackground)
    }

    private var termsList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(viewModel.filteredTerms) { term in
                    DictionaryTermRow(
                        term: term,
                        onToggle: { viewModel.toggleTerm(term) },
                        onEdit: { newText in viewModel.updateTerm(term, newText: newText) },
                        onDelete: { viewModel.deleteTerm(term) }
                    )
                    Rectangle()
                        .fill(DesignConstants.dividerColor)
                        .frame(height: 1)
                        .padding(.leading, 52)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "text.book.closed")
                .font(.system(size: 48))
                .foregroundColor(DesignConstants.tertiaryText)

            Text("Custom Dictionary")
                .font(.headline)
                .foregroundColor(DesignConstants.primaryText)

            Text("Add specialized terms to improve transcription accuracy")
                .font(.subheadline)
                .foregroundColor(DesignConstants.secondaryText)
                .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 8) {
                Text("Examples:")
                    .font(.caption)
                    .foregroundColor(DesignConstants.secondaryText)

                HStack(spacing: 8) {
                    exampleChip("BLK")
                    exampleChip("BPM")
                    exampleChip("OTP")
                }

                HStack(spacing: 8) {
                    exampleChip("next.js")
                    exampleChip("kubectl")
                    exampleChip("zshrc")
                }
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .background(Color.white)
    }

    private var noResultsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 32))
                .foregroundColor(DesignConstants.tertiaryText)

            Text("No Results")
                .font(.headline)
                .foregroundColor(DesignConstants.primaryText)

            Text("No terms match \"\(viewModel.searchText)\"")
                .font(.subheadline)
                .foregroundColor(DesignConstants.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
    }

    private func exampleChip(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundColor(DesignConstants.primaryText)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(DesignConstants.searchBarBackground)
            .cornerRadius(4)
    }
}
