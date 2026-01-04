import Foundation
import Combine
import Cocoa

final class ShortcutManager: KeyEventMonitorDelegate {
    private let configurationManager: ConfigurationManager
    private let audioCaptureService: AudioCaptureService
    private let audioProcessor: AudioProcessor
    private let transcriptionService: TranscriptionService
    private let textOutputManager: TextOutputManager
    private let historyStorage: HistoryStorage
    private let indicatorStateManager: IndicatorStateManager

    private var keyEventMonitor: KeyEventMonitor?
    private var holdTimer: Timer?
    private var recordingTimer: Timer?
    private var warningTimer: Timer?

    private var isRecording = false
    private var isProcessing = false
    private var keyDownTime: Date?
    private var recordingStartTime: Date?

    private var cancellables = Set<AnyCancellable>()

    init(
        configurationManager: ConfigurationManager,
        audioCaptureService: AudioCaptureService,
        audioProcessor: AudioProcessor,
        transcriptionService: TranscriptionService,
        textOutputManager: TextOutputManager,
        historyStorage: HistoryStorage,
        indicatorStateManager: IndicatorStateManager
    ) {
        self.configurationManager = configurationManager
        self.audioCaptureService = audioCaptureService
        self.audioProcessor = audioProcessor
        self.transcriptionService = transcriptionService
        self.textOutputManager = textOutputManager
        self.historyStorage = historyStorage
        self.indicatorStateManager = indicatorStateManager

        setupConfigurationObserver()
    }

    private func setupConfigurationObserver() {
        configurationManager.$configuration
            .sink { [weak self] config in
                self?.updateShortcut(config.triggerShortcut)
            }
            .store(in: &cancellables)
    }

    private func updateShortcut(_ shortcut: ShortcutConfiguration) {
        let wasMonitoring = keyEventMonitor != nil

        if wasMonitoring {
            stopMonitoring()
        }

        keyEventMonitor = KeyEventMonitor(targetKeyCode: shortcut.keyCode)
        keyEventMonitor?.delegate = self

        if wasMonitoring {
            startMonitoring()
        }
    }

    func startMonitoring() {
        let shortcut = configurationManager.configuration.triggerShortcut
        keyEventMonitor = KeyEventMonitor(targetKeyCode: shortcut.keyCode)
        keyEventMonitor?.delegate = self

        if keyEventMonitor?.start() == true {
            Logger.shared.info("Shortcut monitoring started for \(shortcut.displayName)", component: "ShortcutManager")
        } else {
            Logger.shared.error("Failed to start shortcut monitoring", component: "ShortcutManager")
        }
    }

    func stopMonitoring() {
        keyEventMonitor?.stop()
        keyEventMonitor = nil
        cancelRecording()
        Logger.shared.info("Shortcut monitoring stopped", component: "ShortcutManager")
    }

    // MARK: - KeyEventMonitorDelegate

    func keyEventMonitor(_ monitor: KeyEventMonitor, didDetectKeyDown keyCode: UInt16, flags: CGEventFlags) {
        // Ignore if already processing
        guard !isProcessing else {
            Logger.shared.debug("Ignoring key down - processing in progress", component: "ShortcutManager")
            return
        }

        guard !isRecording else {
            Logger.shared.debug("Ignoring key down - already recording", component: "ShortcutManager")
            return
        }

        keyDownTime = Date()

        // Start hold timer
        let holdDuration = Double(configurationManager.configuration.minimumHoldDurationMs) / 1000.0
        holdTimer = Timer.scheduledTimer(withTimeInterval: holdDuration, repeats: false) { [weak self] _ in
            self?.startRecording()
        }

        Logger.shared.debug("Key down detected, starting hold timer", component: "ShortcutManager")
    }

    func keyEventMonitor(_ monitor: KeyEventMonitor, didDetectKeyUp keyCode: UInt16, flags: CGEventFlags) {
        // Cancel hold timer if still waiting
        holdTimer?.invalidate()
        holdTimer = nil

        if isRecording {
            stopRecording()
        } else {
            Logger.shared.debug("Key released before recording started (tap)", component: "ShortcutManager")
        }

        keyDownTime = nil
    }

    func keyEventMonitorDidDetectOtherKey(_ monitor: KeyEventMonitor) {
        // Cancel if another key is pressed during hold/recording
        if holdTimer != nil || isRecording {
            Logger.shared.info("Recording cancelled - another key was pressed", component: "ShortcutManager")
            cancelRecording()
        }
    }

    // MARK: - Recording Control

    private func startRecording() {
        holdTimer = nil

        do {
            try audioCaptureService.startRecording()
            isRecording = true
            recordingStartTime = Date()
            indicatorStateManager.state = .recording

            Logger.shared.info("Recording started", component: "ShortcutManager")

            // Start warning timer (1 minute)
            let warningTime = Double(configurationManager.configuration.warningDurationSeconds)
            warningTimer = Timer.scheduledTimer(withTimeInterval: warningTime, repeats: false) { [weak self] _ in
                self?.showWarning()
            }

            // Start max recording timer (2 minutes)
            let maxTime = Double(configurationManager.configuration.maxRecordingDurationSeconds)
            recordingTimer = Timer.scheduledTimer(withTimeInterval: maxTime, repeats: false) { [weak self] _ in
                self?.stopRecording()
            }

        } catch {
            Logger.shared.error("Failed to start recording: \(error.localizedDescription)", component: "ShortcutManager")
            indicatorStateManager.showError("Failed to start recording")
        }
    }

    private func showWarning() {
        indicatorStateManager.state = .warning
        Logger.shared.info("Recording approaching time limit", component: "ShortcutManager")
    }

    private func stopRecording() {
        warningTimer?.invalidate()
        warningTimer = nil
        recordingTimer?.invalidate()
        recordingTimer = nil

        guard isRecording else { return }

        let recordingDuration = recordingStartTime.map { Date().timeIntervalSince($0) } ?? 0
        let rawAudio = audioCaptureService.stopRecording()
        isRecording = false

        Logger.shared.info("Recording stopped, duration: \(String(format: "%.1f", recordingDuration))s", component: "ShortcutManager")

        // Process the audio
        processAudio(rawAudio, duration: recordingDuration)
    }

    private func cancelRecording() {
        holdTimer?.invalidate()
        holdTimer = nil
        warningTimer?.invalidate()
        warningTimer = nil
        recordingTimer?.invalidate()
        recordingTimer = nil

        if isRecording {
            _ = audioCaptureService.stopRecording()
            isRecording = false
            Logger.shared.info("Recording cancelled", component: "ShortcutManager")
        }

        indicatorStateManager.state = .idle
    }

    // MARK: - Audio Processing

    private func processAudio(_ rawAudio: Data, duration: TimeInterval) {
        isProcessing = true
        indicatorStateManager.state = .processing

        Task {
            do {
                // Process audio (VAD, noise gate, encoding)
                let processedResult = try await audioProcessor.process(rawAudio)

                if processedResult.isEmpty {
                    // No speech detected
                    await MainActor.run {
                        indicatorStateManager.showNoSpeech()
                        isProcessing = false
                    }
                    Logger.shared.info("No speech detected in recording", component: "ShortcutManager")
                    return
                }

                // Transcribe
                let transcriptionResult = try await transcriptionService.transcribe(audio: processedResult.audioData)

                // Apply punctuation stripping if configured
                var finalText = transcriptionResult.text
                if configurationManager.configuration.stripPunctuation {
                    finalText = stripPunctuation(from: finalText)
                }

                await MainActor.run {
                    // Output text
                    textOutputManager.insert(finalText)

                    // Save to history
                    let record = TranscriptionRecord(
                        text: finalText,
                        durationMs: Int(duration * 1000),
                        confidence: transcriptionResult.confidence
                    )
                    historyStorage.save(record)

                    indicatorStateManager.showSuccess()
                    isProcessing = false
                }

                Logger.shared.info("Transcription complete: \(finalText.prefix(50))...", component: "ShortcutManager")

            } catch {
                await MainActor.run {
                    indicatorStateManager.showError(error.localizedDescription)
                    isProcessing = false
                }
                Logger.shared.error("Processing failed: \(error.localizedDescription)", component: "ShortcutManager")
            }
        }
    }

    private func stripPunctuation(from text: String) -> String {
        let punctuation = CharacterSet.punctuationCharacters
        return text.unicodeScalars
            .filter { !punctuation.contains($0) }
            .map { Character($0) }
            .reduce("") { $0 + String($1) }
    }
}
