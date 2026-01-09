import Foundation
@preconcurrency import AVFoundation
import CoreAudio
import AudioToolbox

/// Simple audio sampler for testing microphone input
/// Records up to 10 seconds and plays it back
@Observable
final class AudioSampler: @unchecked Sendable {
    enum State: Sendable {
        case idle
        case recording
        case playing
    }

    private static let maxRecordingDuration: TimeInterval = 10.0

    @MainActor private(set) var state: State = .idle
    @MainActor private(set) var recordingDuration: TimeInterval = 0
    @MainActor private(set) var audioLevel: Float = 0
    @MainActor private(set) var hasRecording: Bool = false

    private let configurationManager: ConfigurationManager
    private var audioEngine: AVAudioEngine?
    private var audioFile: AVAudioFile?
    private var audioPlayer: AVAudioPlayer?
    private var playbackDelegate: PlaybackDelegate?  // Strong reference to prevent deallocation
    private var tempFileURL: URL?
    private var recordingStartTime: Date?
    private var levelTimer: Timer?
    private var durationTimer: Timer?

    private let bufferStorage = SamplerBufferStorage()

    init(configurationManager: ConfigurationManager) {
        self.configurationManager = configurationManager
    }

    // MARK: - Recording

    @MainActor
    func startRecording() throws {
        guard state == .idle else { return }

        // Create temp file for recording
        let tempDir = FileManager.default.temporaryDirectory
        let tempURL = tempDir.appendingPathComponent("talkflow_sample_\(UUID().uuidString).wav")
        self.tempFileURL = tempURL

        // Set up audio engine
        audioEngine = AVAudioEngine()
        guard let engine = audioEngine else {
            throw AudioSamplerError.engineCreationFailed
        }

        let inputNode = engine.inputNode

        // Configure input device if specified
        if let deviceUID = configurationManager.configuration.inputDeviceUID {
            configureInputDevice(uid: deviceUID, inputNode: inputNode)
        }

        // Enable voice processing (voice isolation) if configured
        if configurationManager.configuration.voiceIsolationEnabled {
            do {
                try inputNode.setVoiceProcessingEnabled(true)
                Logger.shared.info("Voice processing enabled for audio sample", component: "AudioSampler")
            } catch {
                Logger.shared.warning("Failed to enable voice processing: \(error)", component: "AudioSampler")
            }
        }

        let inputFormat = inputNode.outputFormat(forBus: 0)

        // Create audio file for recording
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: inputFormat.sampleRate,
            AVNumberOfChannelsKey: inputFormat.channelCount,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false
        ]

        audioFile = try AVAudioFile(forWriting: tempURL, settings: settings)

        // Install tap to capture audio
        bufferStorage.clear()
        Self.installTap(on: inputNode, format: inputFormat, storage: bufferStorage)

        engine.prepare()
        try engine.start()

        state = .recording
        recordingStartTime = Date()
        recordingDuration = 0

        startTimers()

        Logger.shared.info("Audio sampling started", component: "AudioSampler")
    }

    /// Install audio tap - static to avoid MainActor isolation
    private nonisolated static func installTap(
        on inputNode: AVAudioInputNode,
        format: AVAudioFormat,
        storage: SamplerBufferStorage
    ) {
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: format) { buffer, _ in
            storage.append(buffer)
        }
    }

    @MainActor
    func stopRecording() {
        guard state == .recording else { return }

        stopTimers()

        // Stop engine and remove tap
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()

        // Write all captured buffers to file
        writeBuffersToFile()

        audioEngine = nil
        state = .idle
        hasRecording = tempFileURL != nil

        Logger.shared.info("Audio sampling stopped, duration: \(recordingDuration)s", component: "AudioSampler")
    }

    private func writeBuffersToFile() {
        guard let file = audioFile else { return }

        let buffers = bufferStorage.getAllBuffers()
        for buffer in buffers {
            // Convert to the file's processing format if needed
            if let convertedBuffer = convertBuffer(buffer, to: file.processingFormat) {
                do {
                    try file.write(from: convertedBuffer)
                } catch {
                    Logger.shared.error("Failed to write buffer to file: \(error)", component: "AudioSampler")
                }
            }
        }

        audioFile = nil
        bufferStorage.clear()
    }

    private func convertBuffer(_ buffer: AVAudioPCMBuffer, to format: AVAudioFormat) -> AVAudioPCMBuffer? {
        guard buffer.format != format else { return buffer }

        guard let converter = AVAudioConverter(from: buffer.format, to: format) else {
            return nil
        }

        let frameCapacity = AVAudioFrameCount(
            Double(buffer.frameLength) * format.sampleRate / buffer.format.sampleRate
        )

        guard let convertedBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCapacity) else {
            return nil
        }

        var error: NSError?
        let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
            outStatus.pointee = .haveData
            return buffer
        }

        converter.convert(to: convertedBuffer, error: &error, withInputFrom: inputBlock)

        if let error = error {
            Logger.shared.error("Audio conversion error: \(error)", component: "AudioSampler")
            return nil
        }

        return convertedBuffer
    }

    // MARK: - Playback

    @MainActor
    func play() {
        guard state == .idle, let url = tempFileURL else { return }

        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            playbackDelegate = PlaybackDelegate { [weak self] in
                Task { @MainActor in
                    self?.state = .idle
                    self?.playbackDelegate = nil
                }
            }
            audioPlayer?.delegate = playbackDelegate
            audioPlayer?.play()
            state = .playing

            Logger.shared.info("Playing audio sample", component: "AudioSampler")
        } catch {
            Logger.shared.error("Failed to play audio: \(error)", component: "AudioSampler")
        }
    }

    @MainActor
    func stopPlayback() {
        guard state == .playing else { return }

        audioPlayer?.stop()
        audioPlayer = nil
        state = .idle
    }

    // MARK: - Cleanup

    @MainActor
    func clearRecording() {
        stopPlayback()

        if let url = tempFileURL {
            try? FileManager.default.removeItem(at: url)
        }
        tempFileURL = nil
        hasRecording = false
        recordingDuration = 0
    }

    // MARK: - Timers

    @MainActor
    private func startTimers() {
        let storage = bufferStorage

        // Level monitoring
        levelTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let lastBuffer = storage.getLastBuffer() else { return }
            let level = Self.calculateLevel(from: lastBuffer)
            Task { @MainActor in
                self?.audioLevel = level
            }
        }

        // Duration tracking with auto-stop at max
        durationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, let startTime = self.recordingStartTime else { return }
                self.recordingDuration = Date().timeIntervalSince(startTime)

                // Auto-stop at max duration
                if self.recordingDuration >= Self.maxRecordingDuration {
                    self.stopRecording()
                }
            }
        }
    }

    @MainActor
    private func stopTimers() {
        levelTimer?.invalidate()
        levelTimer = nil
        durationTimer?.invalidate()
        durationTimer = nil
        audioLevel = 0
    }

    private static func calculateLevel(from buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData else { return 0 }

        let channelDataPointer = channelData[0]
        let frameLength = Int(buffer.frameLength)

        var sum: Float = 0
        for i in 0..<frameLength {
            let sample = channelDataPointer[i]
            sum += sample * sample
        }

        let rms = sqrt(sum / Float(frameLength))
        let db = 20 * log10(max(rms, 0.00001))

        // Normalize to 0-1 range
        return max(0, min(1, (db + 60) / 60))
    }

    // MARK: - Input Device Configuration

    private nonisolated func configureInputDevice(uid: String, inputNode: AVAudioInputNode) {
        // Get the AudioDeviceID from the UID
        guard let deviceID = getAudioDeviceID(forUID: uid) else {
            Logger.shared.warning("Could not find audio device with UID: \(uid)", component: "AudioSampler")
            return
        }

        // Get the underlying audio unit from the input node
        let audioUnit = inputNode.audioUnit
        guard let unit = audioUnit else {
            Logger.shared.warning("Could not get audio unit from input node", component: "AudioSampler")
            return
        }

        // Set the input device on the audio unit
        var deviceIDValue = deviceID
        let status = AudioUnitSetProperty(
            unit,
            kAudioOutputUnitProperty_CurrentDevice,
            kAudioUnitScope_Global,
            0,
            &deviceIDValue,
            UInt32(MemoryLayout<AudioDeviceID>.size)
        )

        if status == noErr {
            Logger.shared.info("Successfully configured input device for sampler: \(uid) (ID: \(deviceID))", component: "AudioSampler")
        } else {
            Logger.shared.error("Failed to set input device for sampler, OSStatus: \(status)", component: "AudioSampler")
        }
    }

    /// Convert a device UID string to an AudioDeviceID
    private nonisolated func getAudioDeviceID(forUID uid: String) -> AudioDeviceID? {
        var deviceID: AudioDeviceID = 0
        var uidCFString: CFString = uid as CFString

        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDeviceForUID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        // Use withUnsafeMutablePointer to get stable pointers for the translation
        let status = withUnsafeMutablePointer(to: &uidCFString) { uidPointer in
            withUnsafeMutablePointer(to: &deviceID) { devicePointer in
                var translation = AudioValueTranslation(
                    mInputData: UnsafeMutableRawPointer(uidPointer),
                    mInputDataSize: UInt32(MemoryLayout<CFString>.size),
                    mOutputData: UnsafeMutableRawPointer(devicePointer),
                    mOutputDataSize: UInt32(MemoryLayout<AudioDeviceID>.size)
                )

                var dataSize = UInt32(MemoryLayout<AudioValueTranslation>.size)
                return AudioObjectGetPropertyData(
                    AudioObjectID(kAudioObjectSystemObject),
                    &propertyAddress,
                    0,
                    nil,
                    &dataSize,
                    &translation
                )
            }
        }

        if status == noErr && deviceID != kAudioDeviceUnknown {
            return deviceID
        }

        Logger.shared.debug("Failed to translate UID '\(uid)' to device ID, status: \(status)", component: "AudioSampler")
        return nil
    }
}

// MARK: - Playback Delegate

private class PlaybackDelegate: NSObject, AVAudioPlayerDelegate {
    private let onFinish: () -> Void

    init(onFinish: @escaping () -> Void) {
        self.onFinish = onFinish
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        onFinish()
    }
}

// MARK: - Buffer Storage

private final class SamplerBufferStorage: @unchecked Sendable {
    private let queue = DispatchQueue(label: "com.talkflow.samplebuffer", qos: .userInteractive)
    private var buffers: [AVAudioPCMBuffer] = []

    func append(_ buffer: AVAudioPCMBuffer) {
        guard let copy = Self.copyBuffer(buffer) else { return }
        queue.async {
            self.buffers.append(copy)
        }
    }

    func getLastBuffer() -> AVAudioPCMBuffer? {
        queue.sync { buffers.last }
    }

    func getAllBuffers() -> [AVAudioPCMBuffer] {
        queue.sync { buffers }
    }

    func clear() {
        queue.async { self.buffers.removeAll() }
    }

    private static func copyBuffer(_ buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        guard let copy = AVAudioPCMBuffer(pcmFormat: buffer.format, frameCapacity: buffer.frameLength) else {
            return nil
        }
        copy.frameLength = buffer.frameLength

        if let srcData = buffer.floatChannelData, let dstData = copy.floatChannelData {
            for channel in 0..<Int(buffer.format.channelCount) {
                memcpy(dstData[channel], srcData[channel], Int(buffer.frameLength) * MemoryLayout<Float>.size)
            }
        }
        return copy
    }
}

// MARK: - Errors

enum AudioSamplerError: LocalizedError {
    case engineCreationFailed
    case recordingFailed(String)

    var errorDescription: String? {
        switch self {
        case .engineCreationFailed:
            return "Failed to create audio engine"
        case .recordingFailed(let message):
            return "Recording failed: \(message)"
        }
    }
}
