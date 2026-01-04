import Foundation

final class DependencyContainer {
    // MARK: - Configuration

    lazy var configurationManager: ConfigurationManager = {
        ConfigurationManager()
    }()

    // MARK: - Services

    lazy var keychainService: KeychainService = {
        KeychainService()
    }()

    lazy var audioCaptureService: AudioCaptureService = {
        AudioCaptureService(configurationManager: configurationManager)
    }()

    lazy var audioProcessor: AudioProcessor = {
        AudioProcessor(configurationManager: configurationManager)
    }()

    lazy var transcriptionService: TranscriptionService = {
        OpenAIWhisperService(
            keychainService: keychainService,
            configurationManager: configurationManager
        )
    }()

    lazy var textOutputManager: TextOutputManager = {
        TextOutputManager(clipboardManager: clipboardManager)
    }()

    lazy var clipboardManager: ClipboardManager = {
        ClipboardManager()
    }()

    lazy var historyStorage: HistoryStorage = {
        HistoryStorage()
    }()

    // MARK: - Managers

    lazy var indicatorStateManager: IndicatorStateManager = {
        IndicatorStateManager()
    }()

    lazy var shortcutManager: ShortcutManager = {
        ShortcutManager(
            configurationManager: configurationManager,
            audioCaptureService: audioCaptureService,
            audioProcessor: audioProcessor,
            transcriptionService: transcriptionService,
            textOutputManager: textOutputManager,
            historyStorage: historyStorage,
            indicatorStateManager: indicatorStateManager
        )
    }()
}
