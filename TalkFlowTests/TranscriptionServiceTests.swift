import XCTest
@testable import TalkFlow

final class TranscriptionServiceTests: XCTestCase {
    func testNoAPIKeyThrowsError() async {
        let keychainService = MockKeychainService()
        // MockKeychainService starts with no API key

        let configManager = ConfigurationManager()
        let service = OpenAIWhisperService(keychainService: keychainService, configurationManager: configManager)

        do {
            _ = try await service.transcribe(audio: Data())
            XCTFail("Should throw noAPIKey error")
        } catch let error as TranscriptionError {
            switch error {
            case .noAPIKey:
                break // Expected
            default:
                XCTFail("Expected noAPIKey error, got \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
}
