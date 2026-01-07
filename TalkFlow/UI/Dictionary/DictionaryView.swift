import SwiftUI

struct DictionaryView: View {
    var manager: DictionaryManager
    @State private var searchText: String = ""
    @State private var errorMessage: String?
    @State private var showingError = false

    var body: some View {
        VStack(spacing: 0) {
            // Add term input
            AddTermView(isAtLimit: manager.isAtLimit) { term in
                addTerm(term)
            }

            Rectangle()
                .fill(DesignConstants.dividerColor)
                .frame(height: 1)

            // Search bar
            if !manager.terms.isEmpty {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(DesignConstants.secondaryText)

                    TextField("Filter terms...", text: $searchText)
                        .textFieldStyle(.plain)
                        .foregroundColor(DesignConstants.primaryText)

                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(DesignConstants.secondaryText)
                        }
                        .buttonStyle(.plain)
                    }

                    Text("\(manager.termCount)/50")
                        .font(.caption)
                        .foregroundColor(DesignConstants.secondaryText)
                }
                .padding(12)
                .background(DesignConstants.searchBarBackground)

                Rectangle()
                    .fill(DesignConstants.dividerColor)
                    .frame(height: 1)
            }

            // List or empty state
            if manager.terms.isEmpty {
                emptyStateView
            } else if filteredTerms.isEmpty {
                noResultsView
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredTerms) { term in
                            DictionaryTermRow(
                                term: term,
                                onToggle: { toggleTerm(term) },
                                onEdit: { newText in updateTerm(term, newText: newText) },
                                onDelete: { deleteTerm(term) }
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
        }
        .background(Color.white)
        .frame(minWidth: 400, minHeight: 300)
        .task {
            // Refresh terms when view appears to handle race condition during initialization
            await manager.refreshTerms()
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "An unknown error occurred")
        }
    }

    private var filteredTerms: [DictionaryTerm] {
        manager.filterTerms(query: searchText)
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

            Text("No terms match \"\(searchText)\"")
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

    // MARK: - Actions

    private func addTerm(_ term: String) {
        Task {
            do {
                try await manager.addTerm(term)
            } catch let error as DictionaryError {
                await MainActor.run { showError(error.localizedDescription) }
            } catch {
                await MainActor.run { showError(error.localizedDescription) }
            }
        }
    }

    private func updateTerm(_ term: DictionaryTerm, newText: String) {
        Task {
            do {
                try await manager.updateTerm(term, newText: newText)
            } catch let error as DictionaryError {
                await MainActor.run { showError(error.localizedDescription) }
            } catch {
                await MainActor.run { showError(error.localizedDescription) }
            }
        }
    }

    private func toggleTerm(_ term: DictionaryTerm) {
        Task {
            do {
                try await manager.toggleTerm(term)
            } catch let error as DictionaryError {
                await MainActor.run { showError(error.localizedDescription) }
            } catch {
                await MainActor.run { showError(error.localizedDescription) }
            }
        }
    }

    private func deleteTerm(_ term: DictionaryTerm) {
        Task {
            do {
                try await manager.deleteTerm(term)
            } catch let error as DictionaryError {
                await MainActor.run { showError(error.localizedDescription) }
            } catch {
                await MainActor.run { showError(error.localizedDescription) }
            }
        }
    }

    private func showError(_ message: String?) {
        errorMessage = message
        showingError = true
    }
}
