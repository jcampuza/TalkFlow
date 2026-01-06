import SwiftUI

struct HistoryWindow: View {
    @Environment(\.historyStorage) private var historyStorage
    @State private var searcher = HistorySearcher()
    @State private var showingDeleteConfirmation = false
    @State private var recordToDelete: TranscriptionRecord?
    @State private var copiedRecordId: String?
    @State private var allRecords: [TranscriptionRecord] = []

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)

                TextField("Search transcriptions...", text: $searcher.searchText)
                    .textFieldStyle(.plain)

                if !searcher.searchText.isEmpty {
                    Button(action: { searcher.clearSearch() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(12)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // List
            if displayedRecords.isEmpty {
                emptyStateView
            } else {
                List(displayedRecords) { record in
                    HistoryRowView(
                        record: record,
                        isCopied: copiedRecordId == record.id,
                        onCopy: { copyToClipboard(record) },
                        onDelete: { confirmDelete(record) }
                    )
                }
                .listStyle(.inset)
            }
        }
        .frame(minWidth: 500, minHeight: 400)
        .task {
            if let storage = historyStorage {
                searcher.setStorage(storage)
                allRecords = await storage.fetchAll()
            }
        }
        .alert("Delete Transcription?", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                recordToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let record = recordToDelete {
                    Task {
                        try? await historyStorage?.delete(record)
                        if let storage = historyStorage {
                            allRecords = await storage.fetchAll()
                        }
                    }
                    recordToDelete = nil
                }
            }
        } message: {
            Text("This transcription will be permanently deleted.")
        }
    }

    private var displayedRecords: [TranscriptionRecord] {
        if searcher.searchText.isEmpty {
            return allRecords
        } else {
            return searcher.searchResults
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "text.bubble")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            if searcher.searchText.isEmpty {
                Text("No Transcriptions Yet")
                    .font(.headline)
                Text("Your voice transcriptions will appear here")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                Text("No Results")
                    .font(.headline)
                Text("No transcriptions match \"\(searcher.searchText)\"")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func copyToClipboard(_ record: TranscriptionRecord) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(record.text, forType: .string)

        copiedRecordId = record.id

        // Reset copied state after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            if copiedRecordId == record.id {
                copiedRecordId = nil
            }
        }
    }

    private func confirmDelete(_ record: TranscriptionRecord) {
        recordToDelete = record
        showingDeleteConfirmation = true
    }
}

struct HistoryRowView: View {
    let record: TranscriptionRecord
    let isCopied: Bool
    let onCopy: () -> Void
    let onDelete: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(record.text)
                    .lineLimit(3)
                    .font(.body)

                HStack(spacing: 8) {
                    Text(record.relativeTimestamp)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if let duration = record.formattedDuration {
                        Text(duration)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            if isHovering || isCopied {
                HStack(spacing: 8) {
                    Button(action: onCopy) {
                        Label(isCopied ? "Copied!" : "Copy", systemImage: isCopied ? "checkmark" : "doc.on.doc")
                            .labelStyle(.iconOnly)
                            .foregroundColor(isCopied ? .green : .primary)
                    }
                    .buttonStyle(.borderless)
                    .help("Copy to clipboard")

                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.borderless)
                    .help("Delete")
                }
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovering = hovering
        }
        .onTapGesture {
            onCopy()
        }
    }
}
