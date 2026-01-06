import SwiftUI

struct HistoryListView: View {
    @Environment(\.historyStorage) private var historyStorage
    @Binding var selectedRecord: TranscriptionRecord?
    @State private var records: [TranscriptionRecord] = []

    var body: some View {
        List(records, selection: $selectedRecord) { record in
            HistoryListRowView(record: record)
                .tag(record)
        }
        .task {
            if let storage = historyStorage {
                records = await storage.fetchAll()
            }
        }
    }
}

struct HistoryListRowView: View {
    let record: TranscriptionRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(record.preview)
                .lineLimit(2)

            HStack {
                Text(record.relativeTimestamp)
                    .font(.caption)
                    .foregroundColor(.secondary)

                if let duration = record.formattedDuration {
                    Text("•")
                        .foregroundColor(.secondary)
                    Text(duration)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
