import XCTest
@testable import TalkFlow

final class VoiceActivityDetectorTests: XCTestCase {
    var vad: VoiceActivityDetector!

    override func setUp() {
        super.setUp()
        vad = VoiceActivityDetector()
    }

    override func tearDown() {
        vad = nil
        super.tearDown()
    }

    func testEmptySamplesReturnsNoSegments() {
        let segments = vad.detectSpeechSegments(in: [])
        XCTAssertTrue(segments.isEmpty)
    }

    func testSilentSamplesReturnsNoSegments() {
        let silentSamples = [Float](repeating: 0.0, count: 44100)
        let segments = vad.detectSpeechSegments(in: silentSamples)
        XCTAssertTrue(segments.isEmpty)
    }

    func testLoudSamplesDetectsSpeech() {
        // Create samples with audio signal
        var samples = [Float](repeating: 0.0, count: 44100)

        // Add a loud segment in the middle
        for i in 10000..<20000 {
            samples[i] = sin(Float(i) * 0.1) * 0.5
        }

        let segments = vad.detectSpeechSegments(in: samples)
        XCTAssertFalse(segments.isEmpty, "Should detect speech in loud segment")
    }

    func testContainsSpeech() {
        let silentSamples = [Float](repeating: 0.0, count: 44100)
        XCTAssertFalse(vad.containsSpeech(in: silentSamples))

        var loudSamples = [Float](repeating: 0.0, count: 44100)
        for i in 0..<44100 {
            loudSamples[i] = sin(Float(i) * 0.1) * 0.5
        }
        XCTAssertTrue(vad.containsSpeech(in: loudSamples))
    }
}
