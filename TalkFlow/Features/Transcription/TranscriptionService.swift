import Foundation

protocol TranscriptionService: Sendable {
    func transcribe(audio: Data) async throws -> TranscriptionResult
}

enum TranscriptionError: LocalizedError, Sendable {
    case noAPIKey
    case networkError(String)
    case apiError(String)
    case invalidResponse
    case rateLimited
    case maxRetriesExceeded

    var errorDescription: String? {
        switch self {
        case .noAPIKey:
            return "No API key configured. Please add your OpenAI API key in Settings."
        case .networkError(let message):
            return "Network error: \(message)"
        case .apiError(let message):
            return "API error: \(message)"
        case .invalidResponse:
            return "Invalid response from API"
        case .rateLimited:
            return "Rate limited by API. Please try again later."
        case .maxRetriesExceeded:
            return "Transcription failed after multiple attempts"
        }
    }
}
