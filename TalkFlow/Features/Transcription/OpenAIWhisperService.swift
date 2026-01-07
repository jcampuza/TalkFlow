import Foundation

final class OpenAIWhisperService: TranscriptionService, @unchecked Sendable {
    private let keychainService: KeychainServiceProtocol
    private let configurationManager: ConfigurationManager
    private let dictionaryManager: DictionaryManager?

    private let baseURL = URL(string: "https://api.openai.com/v1/audio/transcriptions")!
    private let maxRetries = 3

    init(keychainService: KeychainServiceProtocol, configurationManager: ConfigurationManager, dictionaryManager: DictionaryManager? = nil) {
        self.keychainService = keychainService
        self.configurationManager = configurationManager
        self.dictionaryManager = dictionaryManager
    }

    func transcribe(audio: Data) async throws -> TranscriptionResult {
        guard let apiKey = keychainService.getAPIKey() else {
            throw TranscriptionError.noAPIKey
        }

        var lastError: Error?

        for attempt in 1...maxRetries {
            do {
                let result = try await performTranscription(audio: audio, apiKey: apiKey)
                return result
            } catch let error as TranscriptionError {
                // Don't retry for certain errors
                switch error {
                case .noAPIKey, .apiError:
                    throw error
                case .rateLimited:
                    // Wait before retrying rate limited requests
                    if attempt < maxRetries {
                        try await Task.sleep(nanoseconds: UInt64(attempt * 2_000_000_000))
                    }
                default:
                    break
                }
                lastError = error
                Logger.shared.warning("Transcription attempt \(attempt) failed: \(error.localizedDescription)", component: "WhisperService")
            } catch {
                lastError = error
                Logger.shared.warning("Transcription attempt \(attempt) failed: \(error.localizedDescription)", component: "WhisperService")
            }

            // Brief delay between retries
            if attempt < maxRetries {
                try await Task.sleep(nanoseconds: 500_000_000)
            }
        }

        throw lastError ?? TranscriptionError.maxRetriesExceeded
    }

    private func performTranscription(audio: Data, apiKey: String) async throws -> TranscriptionResult {
        let boundary = UUID().uuidString

        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        let config = configurationManager.configuration

        // Build multipart form data
        var body = Data()

        // Add audio file
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"audio.m4a\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/m4a\r\n\r\n".data(using: .utf8)!)
        body.append(audio)
        body.append("\r\n".data(using: .utf8)!)

        // Add model
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(config.whisperModel)\r\n".data(using: .utf8)!)

        // Add language if specified
        if let language = config.language {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"language\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(language)\r\n".data(using: .utf8)!)
        }

        // Add response format
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"response_format\"\r\n\r\n".data(using: .utf8)!)
        body.append("verbose_json\r\n".data(using: .utf8)!)

        // Add dictionary prompt if available
        if let manager = dictionaryManager {
            let prompt = await MainActor.run { manager.buildPrompt() }
            if !prompt.isEmpty {
                body.append("--\(boundary)\r\n".data(using: .utf8)!)
                body.append("Content-Disposition: form-data; name=\"prompt\"\r\n\r\n".data(using: .utf8)!)
                body.append("\(prompt)\r\n".data(using: .utf8)!)
                Logger.shared.debug("Including dictionary prompt in transcription request", component: "WhisperService")
            }
        }

        // Close boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        Logger.shared.debug("Sending transcription request, audio size: \(audio.count) bytes", component: "WhisperService")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TranscriptionError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200:
            return try parseResponse(data)
        case 401:
            throw TranscriptionError.apiError("Invalid API key")
        case 429:
            throw TranscriptionError.rateLimited
        case 400..<500:
            let errorMessage = parseErrorMessage(data) ?? "Client error"
            throw TranscriptionError.apiError(errorMessage)
        case 500..<600:
            throw TranscriptionError.networkError("Server error (status \(httpResponse.statusCode))")
        default:
            throw TranscriptionError.networkError("Unexpected status code: \(httpResponse.statusCode)")
        }
    }

    private func parseResponse(_ data: Data) throws -> TranscriptionResult {
        struct WhisperResponse: Decodable {
            let text: String
            let language: String?
            let duration: Double?
        }

        let decoder = JSONDecoder()

        do {
            let response = try decoder.decode(WhisperResponse.self, from: data)
            Logger.shared.info("Transcription successful, \(response.text.count) characters", component: "WhisperService")
            return TranscriptionResult(
                text: response.text,
                confidence: nil, // Whisper API doesn't return confidence in the standard response
                language: response.language,
                duration: response.duration
            )
        } catch {
            Logger.shared.error("Failed to parse response: \(error)", component: "WhisperService")
            throw TranscriptionError.invalidResponse
        }
    }

    private func parseErrorMessage(_ data: Data) -> String? {
        struct ErrorResponse: Decodable {
            struct Error: Decodable {
                let message: String
            }
            let error: Error
        }

        guard let response = try? JSONDecoder().decode(ErrorResponse.self, from: data) else {
            return nil
        }

        return response.error.message
    }
}
