import Foundation
import Cocoa

@MainActor
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
    private var gracePeriodTimer: DispatchSourceTimer?

    private var isRecording = false
    private var isProcessing = false
    private var isInGracePeriod = false
    private var keyDownTime: Date?
    private var recordingStartTime: Date?

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
        func observe() {
            withObservationTracking {
                _ = configurationManager.configuration.triggerShortcut
            } onChange: { [weak self] in
                Task { @MainActor in
                    guard let self else { return }
                    self.updateShortcut(self.configurationManager.configuration.triggerShortcut)
                    self.setupConfigurationObserver()  // Re-setup observation
                }
            }
        }
        observe()
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
        // CRITICAL: Stop any existing monitor first to prevent orphaned event taps
        // Orphaned event taps can cause system-wide keyboard freezes
        if keyEventMonitor != nil {
            Logger.shared.warning("Stopping existing monitor before starting new one", component: "ShortcutManager")
            stopMonitoring()
        }

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
        // Handle re-press during grace period - cancel grace period and continue recording
        if isInGracePeriod {
            Logger.shared.debug("Key re-pressed during grace period, continuing recording", component: "ShortcutManager")
            gracePeriodTimer?.cancel()
            gracePeriodTimer = nil
            isInGracePeriod = false
            keyDownTime = Date()
            return
        }

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

        // Start recording immediately if instant mode, otherwise use hold timer
        let holdDurationMs = configurationManager.configuration.minimumHoldDurationMs
        if holdDurationMs == 0 {
            startRecording()
            Logger.shared.debug("Key down detected, instant recording started", component: "ShortcutManager")
        } else {
            let holdDuration = Double(holdDurationMs) / 1000.0
            holdTimer = Timer.scheduledTimer(withTimeInterval: holdDuration, repeats: false) { [weak self] _ in
                Task { @MainActor in
                    self?.startRecording()
                }
            }
            Logger.shared.debug("Key down detected, starting hold timer", component: "ShortcutManager")
        }
    }

    func keyEventMonitor(_ monitor: KeyEventMonitor, didDetectKeyUp keyCode: UInt16, flags: CGEventFlags) {
        // Cancel hold timer if still waiting
        holdTimer?.invalidate()
        holdTimer = nil

        if isRecording && !isInGracePeriod {
            startGracePeriod()
        } else if !isRecording && !isInGracePeriod {
            Logger.shared.debug("Key released before recording started (tap)", component: "ShortcutManager")
        }
        // If in grace period, key release is expected - do nothing

        keyDownTime = nil
    }

    // MARK: - Grace Period

    private func startGracePeriod() {
        let graceDurationMs = configurationManager.configuration.minimumHoldDurationMs
        Logger.shared.debug("Key released, starting grace period of \(graceDurationMs)ms", component: "ShortcutManager")
        isInGracePeriod = true

        gracePeriodTimer = DispatchSource.makeTimerSource(queue: .main)
        gracePeriodTimer?.schedule(deadline: .now() + .milliseconds(Int(graceDurationMs)))
        gracePeriodTimer?.setEventHandler { [weak self] in
            Task { @MainActor in
                self?.gracePeriodEnded()
            }
        }
        gracePeriodTimer?.resume()
    }

    private func gracePeriodEnded() {
        Logger.shared.debug("Grace period ended, stopping recording", component: "ShortcutManager")
        isInGracePeriod = false
        gracePeriodTimer = nil
        stopRecording()
    }

    func keyEventMonitorDidDetectOtherKey(_ monitor: KeyEventMonitor) {
        // Cancel if another key is pressed during hold/recording/grace period
        if holdTimer != nil || isRecording || isInGracePeriod {
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
                Task { @MainActor in
                    self?.showWarning()
                }
            }

            // Start max recording timer (2 minutes)
            let maxTime = Double(configurationManager.configuration.maxRecordingDurationSeconds)
            recordingTimer = Timer.scheduledTimer(withTimeInterval: maxTime, repeats: false) { [weak self] _ in
                Task { @MainActor in
                    self?.stopRecording()
                }
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
        gracePeriodTimer?.cancel()
        gracePeriodTimer = nil
        isInGracePeriod = false

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

        // Capture references to avoid @MainActor isolation issues in Task
        let processor = audioProcessor
        let service = transcriptionService
        let config = configurationManager.configuration
        let outputManager = textOutputManager
        let indicator = indicatorStateManager
        let history = historyStorage

        Task {
            do {
                // Process audio (VAD, noise gate, encoding)
                let processedResult = try await processor.process(rawAudio)

                if processedResult.isEmpty {
                    // No speech detected
                    await MainActor.run {
                        indicator.showNoSpeech()
                        self.isProcessing = false
                    }
                    Logger.shared.info("No speech detected in recording", component: "ShortcutManager")
                    return
                }

                // Transcribe
                let transcriptionResult = try await service.transcribe(audio: processedResult.audioData)

                // Apply punctuation stripping if configured
                var finalText = transcriptionResult.text
                if config.stripPunctuation {
                    finalText = self.stripPunctuation(from: finalText)
                }

                // Skip empty transcriptions
                if finalText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    await MainActor.run {
                        indicator.showNoSpeech()
                        self.isProcessing = false
                    }
                    Logger.shared.info("Transcription returned empty text, skipping", component: "ShortcutManager")
                    return
                }

                await MainActor.run {
                    // Output text
                    outputManager.insert(finalText)

                    indicator.showSuccess()
                    self.isProcessing = false
                }

                // Save to history (async)
                let record = TranscriptionRecord(
                    text: finalText,
                    durationMs: Int(duration * 1000),
                    confidence: transcriptionResult.confidence,
                    source: transcriptionResult.source.rawValue,
                    model: transcriptionResult.model,
                    metadata: transcriptionResult.metadata
                )
                try? await history.save(record)

                Logger.shared.info("Transcription complete: \(finalText.prefix(50))...", component: "ShortcutManager")

            } catch {
                await MainActor.run {
                    indicator.showError(error.localizedDescription)
                    self.isProcessing = false
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
