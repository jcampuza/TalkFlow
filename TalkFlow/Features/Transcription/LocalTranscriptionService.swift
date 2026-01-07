import Foundation
@preconcurrency import WhisperKit

/// Internal struct to hold transcription results from WhisperKit (Sendable)
struct WhisperKitResult: Sendable {
    let text: String
    let language: String?
    let avgLogProb: Double?
    let metadata: String?
    let elapsed: TimeInterval
}

/// Actor to manage WhisperKit state and operations safely across async contexts
/// All WhisperKit operations happen inside this actor to avoid Sendable issues
actor WhisperKitActor {
    private var whisperKit: WhisperKit?
    private var loadedModel: String?

    /// Returns true if we need to load/reload the model
    func needsLoad(for modelName: String) -> Bool {
        return whisperKit == nil || loadedModel != modelName
    }

    /// Returns true if a model is currently loaded
    func isLoaded() -> Bool {
        return whisperKit != nil
    }

    /// Loads a WhisperKit model
    func loadModel(_ modelName: String) async throws {
        Logger.shared.info("Loading local model: \(modelName)", component: "LocalTranscription")

        let startTime = Date()

        // Initialize WhisperKit with the model
        let whisper = try await WhisperKit(
            model: modelName,
            verbose: false,
            logLevel: .error,
            prewarm: false,
            load: true,
            download: true
        )

        let elapsed = Date().timeIntervalSince(startTime)
        Logger.shared.info("Model loaded in \(String(format: "%.2f", elapsed))s", component: "LocalTranscription")

        self.whisperKit = whisper
        self.loadedModel = modelName
    }

    /// Transcribes audio using the loaded model
    func transcribe(audioPath: String, language: String?) async throws -> WhisperKitResult {
        guard let whisper = whisperKit else {
            throw TranscriptionError.modelLoadFailed("WhisperKit not initialized")
        }

        // Configure transcription options
        let decodingOptions = DecodingOptions(
            language: language == "auto" ? nil : language,
            wordTimestamps: true
        )

        // Perform transcription
        let startTime = Date()
        let results = try await whisper.transcribe(audioPath: audioPath, decodeOptions: decodingOptions)
        let elapsed = Date().timeIntervalSince(startTime)

        guard let result = results.first else {
            throw TranscriptionError.localTranscriptionFailed("No transcription result returned")
        }

        let text = result.text.trimmingCharacters(in: .whitespacesAndNewlines)

        Logger.shared.info("Local transcription completed in \(String(format: "%.2f", elapsed))s, \(text.count) characters", component: "LocalTranscription")

        // Extract average log probability from segments
        let avgLogProb: Double? = {
            let segments = result.segments
            guard !segments.isEmpty else { return nil }
            let sum = segments.reduce(0.0) { $0 + Double($1.avgLogprob) }
            return sum / Double(segments.count)
        }()

        // Build metadata JSON
        let metadata = buildMetadata(from: result)

        return WhisperKitResult(
            text: text,
            language: result.language,
            avgLogProb: avgLogProb,
            metadata: metadata,
            elapsed: elapsed
        )
    }

    /// Clears the loaded model
    func clear() {
        whisperKit = nil
        loadedModel = nil
    }

    /// Builds metadata JSON from transcription result including word timestamps
    private func buildMetadata(from result: TranscriptionResult) -> String? {
        var metadata: [String: Any] = [:]

        // Add word-level timestamps if available
        let segments = result.segments
        var wordTimestamps: [[String: Any]] = []
        for segment in segments {
            if let words = segment.words {
                for word in words {
                    wordTimestamps.append([
                        "word": word.word,
                        "start": word.start,
                        "end": word.end,
                        "probability": word.probability
                    ])
                }
            }
        }
        if !wordTimestamps.isEmpty {
            metadata["wordTimestamps"] = wordTimestamps
        }

        // Add language info
        metadata["language"] = result.language

        // Add timing info
        let timings = result.timings
        metadata["audioProcessingTime"] = timings.audioProcessing
        metadata["decodingTime"] = timings.decodingLoop

        guard !metadata.isEmpty else { return nil }

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: metadata)
            return String(data: jsonData, encoding: .utf8)
        } catch {
            Logger.shared.warning("Failed to serialize transcription metadata: \(error)", component: "LocalTranscription")
            return nil
        }
    }
}

/// Service for local on-device transcription using WhisperKit
final class LocalTranscriptionService: TranscriptionService, @unchecked Sendable {
    private let configurationManager: ConfigurationManager
    private let modelManager: ModelManager
    private let whisperActor = WhisperKitActor()

    init(configurationManager: ConfigurationManager, modelManager: ModelManager) {
        self.configurationManager = configurationManager
        self.modelManager = modelManager
    }

    func transcribe(audio: Data) async throws -> TranscriptionOutput {
        // Check if download is in progress
        if await modelManager.isDownloading {
            throw TranscriptionError.downloadInProgress
        }

        // Get selected model
        guard let selectedModel = configurationManager.configuration.selectedLocalModel else {
            throw TranscriptionError.modelNotDownloaded
        }

        // Check if model is downloaded
        guard await modelManager.isModelDownloaded(selectedModel) else {
            throw TranscriptionError.modelNotDownloaded
        }

        // Load or reload model if needed
        if await whisperActor.needsLoad(for: selectedModel) {
            do {
                try await whisperActor.loadModel(selectedModel)
            } catch {
                Logger.shared.error("Failed to load model \(selectedModel): \(error)", component: "LocalTranscription")
                throw TranscriptionError.modelLoadFailed(error.localizedDescription)
            }
        }

        // Write audio data to temp file (WhisperKit needs file path)
        let tempURL = try writeToTempFile(audio)
        defer {
            try? FileManager.default.removeItem(at: tempURL)
        }

        Logger.shared.debug("Starting local transcription, audio size: \(audio.count) bytes", component: "LocalTranscription")

        do {
            let language = configurationManager.configuration.transcriptionLanguage
            let result = try await whisperActor.transcribe(audioPath: tempURL.path, language: language)

            return TranscriptionOutput(
                text: result.text,
                confidence: result.avgLogProb.map { exp($0) },
                language: result.language,
                duration: result.elapsed,
                source: .local,
                model: selectedModel,
                metadata: result.metadata
            )
        } catch let error as TranscriptionError {
            throw error
        } catch {
            Logger.shared.error("Local transcription failed: \(error)", component: "LocalTranscription")
            throw TranscriptionError.localTranscriptionFailed(error.localizedDescription)
        }
    }

    /// Writes audio data to a temporary file for WhisperKit processing
    private func writeToTempFile(_ audio: Data) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let tempURL = tempDir.appendingPathComponent("talkflow_audio_\(UUID().uuidString).m4a")

        do {
            try audio.write(to: tempURL)
            return tempURL
        } catch {
            Logger.shared.error("Failed to write temp audio file: \(error)", component: "LocalTranscription")
            throw TranscriptionError.localTranscriptionFailed("Failed to prepare audio for transcription")
        }
    }

    /// Unloads the current model to free memory
    func unloadModel() async {
        await whisperActor.clear()
        Logger.shared.info("Local model unloaded", component: "LocalTranscription")
    }
}
