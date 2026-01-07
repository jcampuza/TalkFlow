import Foundation

/// Routes transcription requests to the appropriate service based on configuration.
/// This enables immediate mode switching without app restart.
final class TranscriptionRouter: TranscriptionService, @unchecked Sendable {
    private let openAIService: OpenAIWhisperService
    private let localService: LocalTranscriptionService
    private let configurationManager: ConfigurationManager
    private let modelManager: ModelManager

    init(
        openAIService: OpenAIWhisperService,
        localService: LocalTranscriptionService,
        configurationManager: ConfigurationManager,
        modelManager: ModelManager
    ) {
        self.openAIService = openAIService
        self.localService = localService
        self.configurationManager = configurationManager
        self.modelManager = modelManager
    }

    func transcribe(audio: Data) async throws -> TranscriptionOutput {
        let mode = configurationManager.configuration.transcriptionMode

        switch mode {
        case .api:
            Logger.shared.debug("Routing transcription to OpenAI API", component: "TranscriptionRouter")
            return try await openAIService.transcribe(audio: audio)

        case .local:
            Logger.shared.debug("Routing transcription to local model", component: "TranscriptionRouter")
            return try await localService.transcribe(audio: audio)
        }
    }

    /// Returns the current transcription mode
    var currentMode: TranscriptionMode {
        configurationManager.configuration.transcriptionMode
    }

    /// Returns whether local transcription is available (model downloaded and not downloading)
    var isLocalAvailable: Bool {
        get async {
            guard let selectedModel = configurationManager.configuration.selectedLocalModel else {
                return false
            }
            let isDownloading = await modelManager.isDownloading
            let isDownloaded = await modelManager.isModelDownloaded(selectedModel)
            return !isDownloading && isDownloaded
        }
    }

    /// Unloads the local model to free memory
    func unloadLocalModel() async {
        await localService.unloadModel()
    }
}
