import Foundation

struct TranscriptionResult {
    let text: String
    let confidence: Double?
    let language: String?
    let duration: TimeInterval?

    init(text: String, confidence: Double? = nil, language: String? = nil, duration: TimeInterval? = nil) {
        self.text = text
        self.confidence = confidence
        self.language = language
        self.duration = duration
    }
}
