import Foundation

protocol TranscriptionService: Sendable {
    func transcribe(audio: Data) async throws -> TranscriptionOutput
}

enum TranscriptionError: LocalizedError, Sendable {
    case noAPIKey
    case networkError(String)
    case apiError(String)
    case invalidResponse
    case rateLimited
    case maxRetriesExceeded
    // Local transcription errors
    case modelNotDownloaded
    case modelLoadFailed(String)
    case modelCorrupted
    case localTranscriptionFailed(String)
    case downloadFailed(String)
    case insufficientDiskSpace(required: Int64, available: Int64)
    case networkUnavailable
    case downloadInProgress

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
        case .modelNotDownloaded:
            return "Local model not downloaded. Please download a model in Settings."
        case .modelLoadFailed(let message):
            return "Failed to load local model: \(message). Try re-downloading or switch to API mode."
        case .modelCorrupted:
            return "Local model files are corrupted. Please delete and re-download."
        case .localTranscriptionFailed(let message):
            return "Local transcription failed: \(message)"
        case .downloadFailed(let message):
            return "Model download failed: \(message). Please try again."
        case .insufficientDiskSpace(let required, let available):
            let requiredMB = required / (1024 * 1024)
            let availableMB = available / (1024 * 1024)
            return "Not enough disk space. Need \(requiredMB) MB, have \(availableMB) MB available."
        case .networkUnavailable:
            return "No network connection. Cannot download model."
        case .downloadInProgress:
            return "Model download in progress. Please wait for download to complete."
        }
    }
}
