import Foundation
@testable import TalkFlow

final class MockAudioCaptureService: ObservableObject {
    var isRecording = false
    var audioLevel: Float = 0

    private var mockCapturedAudio: CapturedAudio?

    func setMockAudioData(_ data: Data, sampleRate: Double = 44100) {
        mockCapturedAudio = CapturedAudio(data: data, sampleRate: sampleRate)
    }

    func requestMicrophoneAccess(completion: @escaping (Bool) -> Void) {
        completion(true)
    }

    func startRecording() throws {
        isRecording = true
    }

    func stopRecording() -> CapturedAudio {
        isRecording = false
        return mockCapturedAudio ?? .empty
    }
}
