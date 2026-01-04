import SwiftUI

struct HistoryListView: View {
    @EnvironmentObject var historyStorage: HistoryStorage
    @Binding var selectedRecord: TranscriptionRecord?

    var body: some View {
        List(historyStorage.fetchAll(), selection: $selectedRecord) { record in
            HistoryListRowView(record: record)
                .tag(record)
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
