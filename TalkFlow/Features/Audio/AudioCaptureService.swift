import Foundation
import AVFoundation
import Combine

final class AudioCaptureService: ObservableObject {
    private let configurationManager: ConfigurationManager

    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?
    private var audioBuffers: [AVAudioPCMBuffer] = []

    @Published var audioLevel: Float = 0
    @Published var isRecording = false

    private var levelUpdateTimer: Timer?
    private let bufferQueue = DispatchQueue(label: "com.talkflow.audiobuffer", qos: .userInteractive)

    init(configurationManager: ConfigurationManager) {
        self.configurationManager = configurationManager
    }

    func requestMicrophoneAccess(completion: @escaping (Bool) -> Void) {
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

    func startRecording() throws {
        guard !isRecording else {
            throw AudioCaptureError.alreadyRecording
        }

        audioBuffers.removeAll()

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

        // Install tap to capture audio
        inputNode!.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, time in
            self?.handleAudioBuffer(buffer)
        }

        // Prepare and start engine
        audioEngine.prepare()
        try audioEngine.start()

        isRecording = true

        // Start level monitoring
        startLevelMonitoring()

        Logger.shared.info("Audio capture started with format: \(inputFormat)", component: "AudioCapture")
    }

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
        audioBuffers.removeAll()

        Logger.shared.info("Audio capture stopped, captured \(rawData.count) bytes", component: "AudioCapture")

        return rawData
    }

    private func configureInputDevice(uid: String) {
        // Note: Setting specific input device requires more complex AudioUnit configuration
        // For now, we'll use the system default
        Logger.shared.debug("Input device configuration requested: \(uid)", component: "AudioCapture")
    }

    private func handleAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        bufferQueue.async { [weak self] in
            // Create a copy of the buffer to store
            guard let copiedBuffer = self?.copyBuffer(buffer) else { return }
            self?.audioBuffers.append(copiedBuffer)
        }
    }

    private func copyBuffer(_ buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
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

    private func startLevelMonitoring() {
        levelUpdateTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            self?.updateAudioLevel()
        }
    }

    private func stopLevelMonitoring() {
        levelUpdateTimer?.invalidate()
        levelUpdateTimer = nil
        audioLevel = 0
    }

    private func updateAudioLevel() {
        bufferQueue.async { [weak self] in
            guard let self = self, let lastBuffer = self.audioBuffers.last else { return }

            let level = self.calculateRMSLevel(from: lastBuffer)

            DispatchQueue.main.async {
                self.audioLevel = level
            }
        }
    }

    private func calculateRMSLevel(from buffer: AVAudioPCMBuffer) -> Float {
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

    private func convertBuffersToData() -> Data {
        var data = Data()

        for buffer in audioBuffers {
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

    func getAvailableInputDevices() -> [AudioDevice] {
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

    private func getDeviceInfo(deviceID: AudioDeviceID) -> AudioDevice? {
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

struct AudioDevice: Identifiable, Hashable {
    let uid: String
    let name: String

    var id: String { uid }
}

enum AudioCaptureError: LocalizedError {
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
