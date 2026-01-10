import XCTest
@testable import TalkFlow

final class AudioProcessorTests: XCTestCase {
    var configurationManager: ConfigurationManager!
    var audioProcessor: AudioProcessor!

    override func setUp() {
        super.setUp()
        configurationManager = ConfigurationManager()
        audioProcessor = AudioProcessor(configurationManager: configurationManager)
    }

    override func tearDown() {
        audioProcessor = nil
        configurationManager = nil
        super.tearDown()
    }

    func testEmptyAudioReturnsEmpty() async throws {
        let capturedAudio = CapturedAudio(data: Data(), sampleRate: 44100)
        let result = try await audioProcessor.process(capturedAudio)
        XCTAssertTrue(result.isEmpty)
    }

    func testSilenceOnlyReturnsEmpty() async throws {
        // Create silent audio data (all zeros)
        let sampleCount = 44100 * 2 // 2 seconds
        var silentData = Data(capacity: sampleCount * 2)

        for _ in 0..<sampleCount {
            let zero: Int16 = 0
            withUnsafeBytes(of: zero.littleEndian) { bytes in
                silentData.append(contentsOf: bytes)
            }
        }

        let capturedAudio = CapturedAudio(data: silentData, sampleRate: 44100)
        let result = try await audioProcessor.process(capturedAudio)
        XCTAssertTrue(result.isEmpty)
    }
}
