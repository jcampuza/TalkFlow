import Foundation
@testable import TalkFlow

final class MockTranscriptionService: TranscriptionService, @unchecked Sendable {
    var mockResult: TranscriptionResult?
    var mockError: Error?
    var transcribeCallCount = 0

    func transcribe(audio: Data) async throws -> TranscriptionResult {
        transcribeCallCount += 1

        if let error = mockError {
            throw error
        }

        return mockResult ?? TranscriptionResult(text: "Mock transcription")
    }
}
