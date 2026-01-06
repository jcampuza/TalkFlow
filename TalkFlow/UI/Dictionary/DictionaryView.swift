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

            Divider()

            // Search bar
            if !manager.terms.isEmpty {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)

                    TextField("Filter terms...", text: $searchText)
                        .textFieldStyle(.plain)

                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }

                    Text("\(manager.termCount)/50")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(12)
                .background(Color(NSColor.controlBackgroundColor))

                Divider()
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
                            Divider()
                                .padding(.leading, 52)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .frame(minWidth: 400, minHeight: 300)
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
                .foregroundColor(.secondary)

            Text("Custom Dictionary")
                .font(.headline)

            Text("Add specialized terms to improve transcription accuracy")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 8) {
                Text("Examples:")
                    .font(.caption)
                    .foregroundColor(.secondary)

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
    }

    private var noResultsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 32))
                .foregroundColor(.secondary)

            Text("No Results")
                .font(.headline)

            Text("No terms match \"\(searchText)\"")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func exampleChip(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(NSColor.controlBackgroundColor))
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
