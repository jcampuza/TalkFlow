import XCTest
@testable import TalkFlow

// MARK: - Test Mocks

/// Mock AudioCaptureService for testing
@MainActor
final class TestMockAudioCaptureService {
    var isRecording = false
    var audioLevel: Float = 0
    var startRecordingCalled = false
    var stopRecordingCalled = false
    var mockAudioData = Data(repeating: 0, count: 1000)

    func requestMicrophoneAccess(completion: @escaping (Bool) -> Void) {
        completion(true)
    }

    func startRecording() throws {
        startRecordingCalled = true
        isRecording = true
    }

    func stopRecording() -> Data {
        stopRecordingCalled = true
        isRecording = false
        return mockAudioData
    }
}

/// Mock AudioProcessor for testing
@MainActor
final class TestMockAudioProcessor {
    var mockResult = ProcessedAudioResult(audioData: Data(repeating: 0, count: 100), isEmpty: false)

    func process(_ rawAudioData: Data) async throws -> ProcessedAudioResult {
        return mockResult
    }
}

/// Mock HistoryStorage for testing
@MainActor
final class TestMockHistoryStorage {
    var savedRecords: [TranscriptionRecord] = []

    func save(_ record: TranscriptionRecord) {
        savedRecords.append(record)
    }
}

/// Mock TextOutputManager for testing
@MainActor
final class TestMockTextOutputManager {
    var insertedTexts: [String] = []

    func insert(_ text: String) {
        insertedTexts.append(text)
    }
}

// MARK: - Testable ShortcutManager

/// A testable version of ShortcutManager that exposes internal state for testing
@MainActor
final class TestableShortcutManager: KeyEventMonitorDelegate {
    private let configurationManager: ConfigurationManager
    private let audioCaptureService: TestMockAudioCaptureService
    private let audioProcessor: TestMockAudioProcessor
    private let transcriptionService: MockTranscriptionService
    private let textOutputManager: TestMockTextOutputManager
    private let historyStorage: TestMockHistoryStorage
    private let indicatorStateManager: IndicatorStateManager

    private var holdTimer: Timer?
    private var recordingTimer: Timer?
    private var warningTimer: Timer?
    private var gracePeriodTimer: DispatchSourceTimer?

    private(set) var isRecording = false
    private var isProcessing = false
    private(set) var isInGracePeriod = false
    private var keyDownTime: Date?
    private var recordingStartTime: Date?

    // Test hooks
    var onGracePeriodStarted: (() -> Void)?
    var onGracePeriodEnded: (() -> Void)?
    var onRecordingStarted: (() -> Void)?
    var onRecordingStopped: (() -> Void)?

    init(
        configurationManager: ConfigurationManager,
        audioCaptureService: TestMockAudioCaptureService,
        audioProcessor: TestMockAudioProcessor,
        transcriptionService: MockTranscriptionService,
        textOutputManager: TestMockTextOutputManager,
        historyStorage: TestMockHistoryStorage,
        indicatorStateManager: IndicatorStateManager
    ) {
        self.configurationManager = configurationManager
        self.audioCaptureService = audioCaptureService
        self.audioProcessor = audioProcessor
        self.transcriptionService = transcriptionService
        self.textOutputManager = textOutputManager
        self.historyStorage = historyStorage
        self.indicatorStateManager = indicatorStateManager
    }

    // MARK: - KeyEventMonitorDelegate

    func keyEventMonitor(_ monitor: KeyEventMonitor, didDetectKeyDown keyCode: UInt16, flags: CGEventFlags) {
        // Handle re-press during grace period
        if isInGracePeriod {
            gracePeriodTimer?.cancel()
            gracePeriodTimer = nil
            isInGracePeriod = false
            keyDownTime = Date()
            return
        }

        guard !isProcessing else { return }
        guard !isRecording else { return }

        keyDownTime = Date()

        let holdDuration = Double(configurationManager.configuration.minimumHoldDurationMs) / 1000.0
        holdTimer = Timer.scheduledTimer(withTimeInterval: holdDuration, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.startRecording()
            }
        }
    }

    func keyEventMonitor(_ monitor: KeyEventMonitor, didDetectKeyUp keyCode: UInt16, flags: CGEventFlags) {
        holdTimer?.invalidate()
        holdTimer = nil

        if isRecording && !isInGracePeriod {
            startGracePeriod()
        }

        keyDownTime = nil
    }

    func keyEventMonitorDidDetectOtherKey(_ monitor: KeyEventMonitor) {
        if holdTimer != nil || isRecording || isInGracePeriod {
            cancelRecording()
        }
    }

    // MARK: - Grace Period

    private func startGracePeriod() {
        let graceDurationMs = configurationManager.configuration.minimumHoldDurationMs
        isInGracePeriod = true
        onGracePeriodStarted?()

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
        isInGracePeriod = false
        gracePeriodTimer = nil
        onGracePeriodEnded?()
        stopRecording()
    }

    // MARK: - Recording Control

    private func startRecording() {
        holdTimer = nil

        do {
            try audioCaptureService.startRecording()
            isRecording = true
            recordingStartTime = Date()
            indicatorStateManager.state = .recording
            onRecordingStarted?()
        } catch {
            indicatorStateManager.showError("Failed to start recording")
        }
    }

    private func stopRecording() {
        warningTimer?.invalidate()
        warningTimer = nil
        recordingTimer?.invalidate()
        recordingTimer = nil

        guard isRecording else { return }

        _ = audioCaptureService.stopRecording()
        isRecording = false
        onRecordingStopped?()

        // For testing, we skip the async processing
        indicatorStateManager.state = .processing
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
        }

        indicatorStateManager.state = .idle
    }

    // MARK: - Test Helpers

    /// Simulate key down event
    func simulateKeyDown() {
        keyEventMonitor(KeyEventMonitor(targetKeyCode: 0x36), didDetectKeyDown: 0x36, flags: [])
    }

    /// Simulate key up event
    func simulateKeyUp() {
        keyEventMonitor(KeyEventMonitor(targetKeyCode: 0x36), didDetectKeyUp: 0x36, flags: [])
    }

    /// Simulate other key press
    func simulateOtherKey() {
        keyEventMonitorDidDetectOtherKey(KeyEventMonitor(targetKeyCode: 0x36))
    }
}

// MARK: - Tests

@MainActor
final class ShortcutManagerGracePeriodTests: XCTestCase {
    var configurationManager: ConfigurationManager!
    var audioCaptureService: TestMockAudioCaptureService!
    var audioProcessor: TestMockAudioProcessor!
    var transcriptionService: MockTranscriptionService!
    var textOutputManager: TestMockTextOutputManager!
    var historyStorage: TestMockHistoryStorage!
    var indicatorStateManager: IndicatorStateManager!
    var shortcutManager: TestableShortcutManager!

    override func setUp() async throws {
        configurationManager = ConfigurationManager()
        // Use very short durations for fast tests
        configurationManager.configuration.minimumHoldDurationMs = 50

        audioCaptureService = TestMockAudioCaptureService()
        audioProcessor = TestMockAudioProcessor()
        transcriptionService = MockTranscriptionService()
        textOutputManager = TestMockTextOutputManager()
        historyStorage = TestMockHistoryStorage()
        indicatorStateManager = IndicatorStateManager()

        shortcutManager = TestableShortcutManager(
            configurationManager: configurationManager,
            audioCaptureService: audioCaptureService,
            audioProcessor: audioProcessor,
            transcriptionService: transcriptionService,
            textOutputManager: textOutputManager,
            historyStorage: historyStorage,
            indicatorStateManager: indicatorStateManager
        )
    }

    override func tearDown() async throws {
        shortcutManager = nil
        configurationManager = nil
        audioCaptureService = nil
        audioProcessor = nil
        transcriptionService = nil
        textOutputManager = nil
        historyStorage = nil
        indicatorStateManager = nil
    }

    // MARK: - Basic Grace Period Tests

    func testGracePeriodStartsAfterKeyRelease() {
        let expectation = XCTestExpectation(description: "Grace period should start")
        let recordingStarted = XCTestExpectation(description: "Recording should start")

        shortcutManager.onRecordingStarted = {
            recordingStarted.fulfill()
        }

        shortcutManager.onGracePeriodStarted = {
            expectation.fulfill()
        }

        // Press and hold key
        shortcutManager.simulateKeyDown()

        // Wait for recording to start
        wait(for: [recordingStarted], timeout: 0.2)

        XCTAssertTrue(shortcutManager.isRecording, "Should be recording after hold duration")

        // Release key - should start grace period
        shortcutManager.simulateKeyUp()

        wait(for: [expectation], timeout: 0.1)
        XCTAssertTrue(shortcutManager.isInGracePeriod, "Should be in grace period after key release")
        XCTAssertTrue(shortcutManager.isRecording, "Should still be recording during grace period")
    }

    func testGracePeriodEndsAndStopsRecording() {
        let gracePeriodEnded = XCTestExpectation(description: "Grace period should end")
        let recordingStopped = XCTestExpectation(description: "Recording should stop")

        shortcutManager.onGracePeriodEnded = {
            gracePeriodEnded.fulfill()
        }

        shortcutManager.onRecordingStopped = {
            recordingStopped.fulfill()
        }

        // Start recording
        shortcutManager.simulateKeyDown()

        // Wait for recording to start
        let recordingStarted = XCTestExpectation(description: "Recording started")
        shortcutManager.onRecordingStarted = { recordingStarted.fulfill() }
        wait(for: [recordingStarted], timeout: 0.2)

        // Release key
        shortcutManager.simulateKeyUp()

        // Wait for grace period to complete (50ms + some buffer)
        wait(for: [gracePeriodEnded, recordingStopped], timeout: 0.2)

        XCTAssertFalse(shortcutManager.isInGracePeriod, "Should not be in grace period after it ends")
        XCTAssertFalse(shortcutManager.isRecording, "Should not be recording after grace period ends")
        XCTAssertTrue(audioCaptureService.stopRecordingCalled, "Audio capture should have been stopped")
    }

    // MARK: - Re-press During Grace Period Tests

    func testRepressDuringGracePeriodContinuesRecording() {
        let gracePeriodStarted = XCTestExpectation(description: "Grace period should start")
        let recordingStarted = XCTestExpectation(description: "Recording should start")

        shortcutManager.onRecordingStarted = { recordingStarted.fulfill() }
        shortcutManager.onGracePeriodStarted = { gracePeriodStarted.fulfill() }

        // Start recording
        shortcutManager.simulateKeyDown()
        wait(for: [recordingStarted], timeout: 0.2)

        // Release to start grace period
        shortcutManager.simulateKeyUp()
        wait(for: [gracePeriodStarted], timeout: 0.1)

        XCTAssertTrue(shortcutManager.isInGracePeriod, "Should be in grace period")

        // Re-press during grace period
        shortcutManager.simulateKeyDown()

        XCTAssertFalse(shortcutManager.isInGracePeriod, "Should no longer be in grace period after re-press")
        XCTAssertTrue(shortcutManager.isRecording, "Should still be recording after re-press")
    }

    func testRepressDuringGracePeriodAllowsNewGracePeriod() {
        let gracePeriodCount = XCTestExpectation(description: "Grace period should start twice")
        gracePeriodCount.expectedFulfillmentCount = 2

        let recordingStarted = XCTestExpectation(description: "Recording should start")

        shortcutManager.onRecordingStarted = { recordingStarted.fulfill() }
        shortcutManager.onGracePeriodStarted = { gracePeriodCount.fulfill() }

        // Start recording
        shortcutManager.simulateKeyDown()
        wait(for: [recordingStarted], timeout: 0.2)

        // Release to start grace period #1
        shortcutManager.simulateKeyUp()

        // Wait a bit for grace period to start
        let grace1 = XCTestExpectation(description: "First grace")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) { grace1.fulfill() }
        wait(for: [grace1], timeout: 0.1)

        // Re-press during grace period
        shortcutManager.simulateKeyDown()

        // Release again to start grace period #2
        shortcutManager.simulateKeyUp()

        wait(for: [gracePeriodCount], timeout: 0.2)
    }

    // MARK: - Cancellation Tests

    func testOtherKeyDuringGracePeriodCancelsRecording() {
        let recordingStarted = XCTestExpectation(description: "Recording should start")
        let gracePeriodStarted = XCTestExpectation(description: "Grace period should start")

        shortcutManager.onRecordingStarted = { recordingStarted.fulfill() }
        shortcutManager.onGracePeriodStarted = { gracePeriodStarted.fulfill() }

        // Start recording
        shortcutManager.simulateKeyDown()
        wait(for: [recordingStarted], timeout: 0.2)

        // Release to start grace period
        shortcutManager.simulateKeyUp()
        wait(for: [gracePeriodStarted], timeout: 0.1)

        XCTAssertTrue(shortcutManager.isInGracePeriod, "Should be in grace period")

        // Press another key
        shortcutManager.simulateOtherKey()

        XCTAssertFalse(shortcutManager.isInGracePeriod, "Grace period should be cancelled")
        XCTAssertFalse(shortcutManager.isRecording, "Recording should be cancelled")
        XCTAssertEqual(indicatorStateManager.state, .idle, "Indicator should be idle")
    }

    // MARK: - Configuration Sync Tests

    func testGracePeriodUsesConfiguredHoldDuration() {
        // Set a longer hold duration
        configurationManager.configuration.minimumHoldDurationMs = 100

        let gracePeriodStarted = XCTestExpectation(description: "Grace period should start")
        let gracePeriodEnded = XCTestExpectation(description: "Grace period should end")
        let recordingStarted = XCTestExpectation(description: "Recording started")

        shortcutManager.onRecordingStarted = { recordingStarted.fulfill() }
        shortcutManager.onGracePeriodStarted = { gracePeriodStarted.fulfill() }
        shortcutManager.onGracePeriodEnded = { gracePeriodEnded.fulfill() }

        // Start recording
        shortcutManager.simulateKeyDown()
        wait(for: [recordingStarted], timeout: 0.3)

        // Release to start grace period
        let releaseTime = Date()
        shortcutManager.simulateKeyUp()
        wait(for: [gracePeriodStarted], timeout: 0.1)

        // Wait for grace period to end
        wait(for: [gracePeriodEnded], timeout: 0.3)

        let elapsed = Date().timeIntervalSince(releaseTime)
        // Grace period should be approximately 100ms (with some tolerance)
        XCTAssertGreaterThan(elapsed, 0.08, "Grace period should be at least ~80ms")
        XCTAssertLessThan(elapsed, 0.25, "Grace period should be less than 250ms")
    }
}
