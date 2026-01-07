import Foundation
import GRDB

struct TranscriptionRecord: Codable, Identifiable, Hashable, FetchableRecord, PersistableRecord, Sendable {
    var id: String
    var text: String
    var timestamp: Date
    var durationMs: Int?
    var confidence: Double?
    var createdAt: Date

    static let databaseTableName = "transcriptions"

    init(id: String = UUID().uuidString, text: String, timestamp: Date = Date(), durationMs: Int? = nil, confidence: Double? = nil, createdAt: Date = Date()) {
        self.id = id
        self.text = text
        self.timestamp = timestamp
        self.durationMs = durationMs
        self.confidence = confidence
        self.createdAt = createdAt
    }

    // MARK: - FetchableRecord

    init(row: Row) {
        id = row["id"]
        text = row["text"]
        timestamp = row["timestamp"]
        durationMs = row["duration_ms"]
        confidence = row["confidence"]
        createdAt = row["created_at"]
    }

    // MARK: - PersistableRecord

    func encode(to container: inout PersistenceContainer) {
        container["id"] = id
        container["text"] = text
        container["timestamp"] = timestamp
        container["duration_ms"] = durationMs
        container["confidence"] = confidence
        container["created_at"] = createdAt
    }

    // MARK: - Display Helpers

    var preview: String {
        let maxLength = 100
        if text.count <= maxLength {
            return text
        }
        return String(text.prefix(maxLength)) + "..."
    }

    var formattedDuration: String? {
        guard let ms = durationMs else { return nil }
        let seconds = Double(ms) / 1000.0
        return String(format: "%.1fs", seconds)
    }

    var relativeTimestamp: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: timestamp, relativeTo: Date())
    }
}

// MARK: - Full-Text Search Support

extension TranscriptionRecord {
    static func matching(_ pattern: String) -> SQLRequest<TranscriptionRecord> {
        let sql = """
            SELECT transcriptions.*
            FROM transcriptions
            JOIN transcriptions_fts ON transcriptions_fts.rowid = transcriptions.rowid
            WHERE transcriptions_fts MATCH ?
            ORDER BY transcriptions.timestamp DESC
        """
        return SQLRequest(sql: sql, arguments: [pattern])
    }
}
