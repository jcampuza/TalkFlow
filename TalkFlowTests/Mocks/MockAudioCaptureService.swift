import Foundation
@testable import TalkFlow

final class MockAudioCaptureService: ObservableObject {
    var isRecording = false
    var audioLevel: Float = 0

    private var mockAudioData: Data?

    func setMockAudioData(_ data: Data) {
        mockAudioData = data
    }

    func requestMicrophoneAccess(completion: @escaping (Bool) -> Void) {
        completion(true)
    }

    func startRecording() throws {
        isRecording = true
    }

    func stopRecording() -> Data {
        isRecording = false
        return mockAudioData ?? Data()
    }
}
