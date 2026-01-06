import SwiftUI

struct MenuBarMenu: View {
    @Environment(\.historyStorage) private var historyStorage

    let onShowHistory: () -> Void
    let onShowSettings: () -> Void
    let onQuit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let storage = historyStorage, !storage.recentRecords.isEmpty {
                Text("Recent Transcriptions")
                    .font(.caption)
                    .foregroundColor(.secondary)

                ForEach(storage.recentRecords.prefix(5)) { record in
                    Button(action: {
                        copyToClipboard(record.text)
                    }) {
                        HStack {
                            Text(record.preview)
                                .lineLimit(1)
                            Spacer()
                            Text(record.relativeTimestamp)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }

                Divider()
            }

            Button("View All History...") {
                onShowHistory()
            }

            Divider()

            Button("Settings...") {
                onShowSettings()
            }

            Divider()

            Button("Quit TalkFlow") {
                onQuit()
            }
        }
        .padding(8)
        .frame(minWidth: 250)
    }

    private func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}
