import Foundation

/// Source of the transcription
enum TranscriptionSource: String, Codable, Sendable {
    case api = "api"
    case local = "local"
}

struct TranscriptionOutput: Sendable {
    let text: String
    let confidence: Double?
    let language: String?
    let duration: TimeInterval?
    let source: TranscriptionSource
    let model: String?
    let metadata: String?  // JSON string for word timestamps, etc.

    init(
        text: String,
        confidence: Double? = nil,
        language: String? = nil,
        duration: TimeInterval? = nil,
        source: TranscriptionSource = .api,
        model: String? = nil,
        metadata: String? = nil
    ) {
        self.text = text
        self.confidence = confidence
        self.language = language
        self.duration = duration
        self.source = source
        self.model = model
        self.metadata = metadata
    }
}
