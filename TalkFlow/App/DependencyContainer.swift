import Foundation

@MainActor
final class DependencyContainer {
    // MARK: - Configuration

    lazy var configurationManager: ConfigurationManager = {
        ConfigurationManager()
    }()

    // MARK: - Core Services

    lazy var keychainService: KeychainService = {
        KeychainService()
    }()

    lazy var clipboardManager: ClipboardManager = {
        ClipboardManager()
    }()

    // MARK: - Storage

    lazy var historyStorage: HistoryStorage = {
        HistoryStorage()
    }()

    lazy var dictionaryStorage: DictionaryStorage = {
        DictionaryStorage()
    }()

    // MARK: - Dictionary

    lazy var dictionaryManager: DictionaryManager = {
        DictionaryManager(storage: dictionaryStorage)
    }()

    // MARK: - Audio Services

    lazy var audioCaptureService: AudioCaptureService = {
        AudioCaptureService(configurationManager: configurationManager)
    }()

    lazy var audioProcessor: AudioProcessor = {
        AudioProcessor(configurationManager: configurationManager)
    }()

    // MARK: - Transcription

    lazy var transcriptionService: TranscriptionService = {
        OpenAIWhisperService(
            keychainService: keychainService,
            configurationManager: configurationManager,
            dictionaryManager: dictionaryManager
        )
    }()

    // MARK: - Output

    lazy var textOutputManager: TextOutputManager = {
        TextOutputManager(clipboardManager: clipboardManager)
    }()

    // MARK: - Managers

    lazy var indicatorStateManager: IndicatorStateManager = {
        IndicatorStateManager()
    }()

    lazy var onboardingManager: OnboardingManager = {
        OnboardingManager()
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
