import Foundation
@testable import TalkFlow

final class MockTranscriptionService: TranscriptionService, @unchecked Sendable {
    var mockResult: TranscriptionOutput?
    var mockError: Error?
    var transcribeCallCount = 0

    func transcribe(audio: Data) async throws -> TranscriptionOutput {
        transcribeCallCount += 1

        if let error = mockError {
            throw error
        }

        return mockResult ?? TranscriptionOutput(text: "Mock transcription")
    }
}
