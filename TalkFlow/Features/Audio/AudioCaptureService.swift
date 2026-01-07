import Foundation
import AVFoundation

/// Thread-safe buffer storage for audio capture
/// This class is separate from AudioCaptureService to avoid MainActor isolation issues
/// when the audio tap callback needs to store buffers from the realtime audio thread
private final class AudioBufferStorage: @unchecked Sendable {
    private let queue = DispatchQueue(label: "com.talkflow.audiobuffer", qos: .userInteractive)
    private var buffers: [AVAudioPCMBuffer] = []

    func append(_ buffer: AVAudioPCMBuffer) {
        queue.async {
            self.buffers.append(buffer)
        }
    }

    func getLastBuffer() -> AVAudioPCMBuffer? {
        queue.sync {
            buffers.last
        }
    }

    func getAllBuffers() -> [AVAudioPCMBuffer] {
        queue.sync {
            buffers
        }
    }

    func clear() {
        queue.async {
            self.buffers.removeAll()
        }
    }
}

@Observable
final class AudioCaptureService: @unchecked Sendable {
    private let configurationManager: ConfigurationManager

    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?
    private let bufferStorage = AudioBufferStorage()

    @MainActor var audioLevel: Float = 0
    @MainActor var isRecording = false

    private var levelUpdateTimer: Timer?

    init(configurationManager: ConfigurationManager) {
        self.configurationManager = configurationManager
    }

    func requestMicrophoneAccess(completion: @escaping @Sendable (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            completion(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                DispatchQueue.main.async {
                    completion(granted)
                }
            }
        case .denied, .restricted:
            completion(false)
        @unknown default:
            completion(false)
        }
    }

    @MainActor
    func startRecording() throws {
        guard !isRecording else {
            throw AudioCaptureError.alreadyRecording
        }

        bufferStorage.clear()

        audioEngine = AVAudioEngine()
        guard let audioEngine = audioEngine else {
            throw AudioCaptureError.engineCreationFailed
        }

        inputNode = audioEngine.inputNode

        // Configure input device if specified
        if let deviceUID = configurationManager.configuration.inputDeviceUID {
            configureInputDevice(uid: deviceUID)
        }

        let inputFormat = inputNode!.outputFormat(forBus: 0)

        // CRITICAL: Install tap using a nonisolated static function
        // The closure MUST be defined in a nonisolated context to avoid
        // inheriting MainActor isolation, which would crash when called
        // from the realtime audio thread
        Self.installAudioTap(on: inputNode!, format: inputFormat, storage: bufferStorage)

        // Prepare and start engine
        audioEngine.prepare()
        try audioEngine.start()

        isRecording = true

        // Start level monitoring
        startLevelMonitoring()

        Logger.shared.info("Audio capture started with format: \(inputFormat)", component: "AudioCapture")
    }

    /// Install audio tap on the input node
    /// MUST be nonisolated static to ensure the closure doesn't inherit MainActor isolation
    /// The audio tap callback is called from a realtime audio thread, NOT the main thread
    private nonisolated static func installAudioTap(
        on inputNode: AVAudioInputNode,
        format: AVAudioFormat,
        storage: AudioBufferStorage
    ) {
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: format) { buffer, _ in
            // This closure runs on the realtime audio thread
            // It must NOT have MainActor isolation
            if let copiedBuffer = copyBuffer(buffer) {
                storage.append(copiedBuffer)
            }
        }
    }

    @MainActor
    func stopRecording() -> Data {
        guard isRecording else {
            return Data()
        }

        stopLevelMonitoring()

        inputNode?.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        inputNode = nil

        isRecording = false

        // Convert buffers to raw PCM data
        let rawData = convertBuffersToData()
        bufferStorage.clear()

        Logger.shared.info("Audio capture stopped, captured \(rawData.count) bytes", component: "AudioCapture")

        return rawData
    }

    private nonisolated func configureInputDevice(uid: String) {
        // Note: Setting specific input device requires more complex AudioUnit configuration
        // For now, we'll use the system default
        Logger.shared.debug("Input device configuration requested: \(uid)", component: "AudioCapture")
    }

    /// Copy an audio buffer - static so it can be called from the audio tap without capturing self
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

    @MainActor
    private func startLevelMonitoring() {
        // Capture bufferStorage to avoid capturing self in the timer callback
        let storage = bufferStorage
        levelUpdateTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let lastBuffer = storage.getLastBuffer() else { return }
            let level = AudioCaptureService.calculateRMSLevel(from: lastBuffer)
            Task { @MainActor in
                self?.audioLevel = level
            }
        }
    }

    @MainActor
    private func stopLevelMonitoring() {
        levelUpdateTimer?.invalidate()
        levelUpdateTimer = nil
        audioLevel = 0
    }

    private static func calculateRMSLevel(from buffer: AVAudioPCMBuffer) -> Float {
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

        // Normalize to 0-1 range (assuming -60dB to 0dB range)
        return max(0, min(1, (db + 60) / 60))
    }

    private nonisolated func convertBuffersToData() -> Data {
        var data = Data()

        for buffer in bufferStorage.getAllBuffers() {
            if let channelData = buffer.floatChannelData {
                let frameLength = Int(buffer.frameLength)
                let channelDataPointer = channelData[0]

                // Convert Float samples to Int16 for better compression later
                for i in 0..<frameLength {
                    let sample = channelDataPointer[i]
                    let clampedSample = max(-1, min(1, sample))
                    let int16Sample = Int16(clampedSample * Float(Int16.max))

                    withUnsafeBytes(of: int16Sample.littleEndian) { bytes in
                        data.append(contentsOf: bytes)
                    }
                }
            }
        }

        return data
    }

    nonisolated func getAvailableInputDevices() -> [AudioDevice] {
        var devices: [AudioDevice] = []

        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var dataSize: UInt32 = 0
        AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &propertyAddress, 0, nil, &dataSize)

        let deviceCount = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = [AudioDeviceID](repeating: 0, count: deviceCount)

        AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &propertyAddress, 0, nil, &dataSize, &deviceIDs)

        for deviceID in deviceIDs {
            // Check if device has input channels
            var inputPropertyAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyStreamConfiguration,
                mScope: kAudioDevicePropertyScopeInput,
                mElement: kAudioObjectPropertyElementMain
            )

            var inputDataSize: UInt32 = 0
            if AudioObjectGetPropertyDataSize(deviceID, &inputPropertyAddress, 0, nil, &inputDataSize) == noErr {
                let bufferListPointer = UnsafeMutablePointer<AudioBufferList>.allocate(capacity: 1)
                defer { bufferListPointer.deallocate() }

                if AudioObjectGetPropertyData(deviceID, &inputPropertyAddress, 0, nil, &inputDataSize, bufferListPointer) == noErr {
                    let bufferList = bufferListPointer.pointee
                    if bufferList.mNumberBuffers > 0 {
                        // This device has input channels
                        if let device = getDeviceInfo(deviceID: deviceID) {
                            devices.append(device)
                        }
                    }
                }
            }
        }

        return devices
    }

    private nonisolated func getDeviceInfo(deviceID: AudioDeviceID) -> AudioDevice? {
        // Get device name
        var namePropertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceNameCFString,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var name: CFString = "" as CFString
        var dataSize = UInt32(MemoryLayout<CFString>.size)

        guard AudioObjectGetPropertyData(deviceID, &namePropertyAddress, 0, nil, &dataSize, &name) == noErr else {
            return nil
        }

        // Get device UID
        var uidPropertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceUID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var uid: CFString = "" as CFString
        dataSize = UInt32(MemoryLayout<CFString>.size)

        guard AudioObjectGetPropertyData(deviceID, &uidPropertyAddress, 0, nil, &dataSize, &uid) == noErr else {
            return nil
        }

        return AudioDevice(uid: uid as String, name: name as String)
    }
}

struct AudioDevice: Identifiable, Hashable, Sendable {
    let uid: String
    let name: String

    var id: String { uid }
}

enum AudioCaptureError: LocalizedError, Sendable {
    case alreadyRecording
    case engineCreationFailed
    case deviceDisconnected

    var errorDescription: String? {
        switch self {
        case .alreadyRecording:
            return "Already recording"
        case .engineCreationFailed:
            return "Failed to create audio engine"
        case .deviceDisconnected:
            return "Audio device disconnected"
        }
    }
}
