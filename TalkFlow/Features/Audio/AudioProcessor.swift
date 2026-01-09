import Foundation
import AVFoundation
import Accelerate

struct ProcessedAudioResult: Sendable {
    let audioData: Data
    let isEmpty: Bool

    static let empty = ProcessedAudioResult(audioData: Data(), isEmpty: true)
}

final class AudioProcessor: @unchecked Sendable {
    private let configurationManager: ConfigurationManager

    /// Debug audio file writing is automatically enabled in DEBUG builds only
    #if DEBUG
    static let debugAudioEnabled = true
    #else
    static let debugAudioEnabled = false
    #endif

    init(configurationManager: ConfigurationManager) {
        self.configurationManager = configurationManager
    }

    /// Create a noise gate with current config and sample rate
    private func makeNoiseGate(sampleRate: Float) -> NoiseGate {
        let threshold = configurationManager.configuration.noiseGateThresholdDb
        Logger.shared.debug("Creating NoiseGate with threshold: \(threshold) dB, sampleRate: \(sampleRate)", component: "AudioProcessor")
        return NoiseGate(thresholdDb: threshold, sampleRate: sampleRate)
    }

    /// Create a VAD with current config and sample rate
    private func makeVoiceActivityDetector(sampleRate: Double) -> VoiceActivityDetector {
        let threshold = configurationManager.configuration.silenceThresholdDb
        Logger.shared.debug("Creating VAD with silenceThreshold: \(threshold) dB, sampleRate: \(sampleRate)", component: "AudioProcessor")
        return VoiceActivityDetector(sampleRate: sampleRate, silenceThresholdDb: threshold)
    }

    /// Debug directory for audio files
    /// Files are written to ~/Library/Containers/com.josephcampuzano.TalkFlow/Data/Documents/TalkFlow-Debug/
    /// Or in non-sandboxed mode: ~/Documents/TalkFlow-Debug/
    private var debugDirectory: URL {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return documentsURL.appendingPathComponent("TalkFlow-Debug")
    }

    /// Write debug audio file at a specific processing stage
    private func writeDebugAudio(samples: [Float], sampleRate: Int, stage: String) {
        guard Self.debugAudioEnabled else { return }

        do {
            // Create debug directory if needed
            try FileManager.default.createDirectory(at: debugDirectory, withIntermediateDirectories: true)

            // Log the full path on first write so user can find it
            if stage == "1_raw" {
                Logger.shared.info("Debug audio directory: \(debugDirectory.path)", component: "AudioProcessor")
            }

            // Create timestamped filename
            let formatter = DateFormatter()
            formatter.dateFormat = "HH-mm-ss"
            let timestamp = formatter.string(from: Date())
            let filename = "\(timestamp)_\(stage).wav"
            let fileURL = debugDirectory.appendingPathComponent(filename)

            // Convert to PCM and write WAV
            let pcmData = convertToPCMData(samples: samples)
            try writeWAVFile(pcmData: pcmData, sampleRate: sampleRate, url: fileURL)

            Logger.shared.info("Debug audio written: \(filename) (\(samples.count) samples)", component: "AudioProcessor")
        } catch {
            Logger.shared.error("Failed to write debug audio: \(error)", component: "AudioProcessor")
        }
    }

    func process(_ capturedAudio: CapturedAudio) async throws -> ProcessedAudioResult {
        let rawAudioData = capturedAudio.data
        let sampleRate = Int(capturedAudio.sampleRate)

        Logger.shared.debug("Processing \(rawAudioData.count) bytes of raw audio at \(sampleRate) Hz", component: "AudioProcessor")

        // Convert raw PCM data (Int16) to Float samples
        var samples = convertToFloatSamples(rawAudioData)

        guard !samples.isEmpty else {
            Logger.shared.debug("No samples to process", component: "AudioProcessor")
            return .empty
        }

        // DEBUG: Write raw audio before any processing
        writeDebugAudio(samples: samples, sampleRate: sampleRate, stage: "1_raw")

        // Check if audio processing is disabled
        let bypassProcessing = configurationManager.configuration.bypassAudioProcessing

        if bypassProcessing {
            Logger.shared.info("Audio processing bypassed (noise gate and VAD disabled)", component: "AudioProcessor")
            // DEBUG: Write audio (same as raw since no processing)
            writeDebugAudio(samples: samples, sampleRate: sampleRate, stage: "3_final_speech_bypassed")
            let compressedData = try await encodeToAAC(samples: samples, sampleRate: Double(sampleRate))
            return ProcessedAudioResult(audioData: compressedData, isEmpty: false)
        }

        // Create processors with current config and correct sample rate
        let noiseGate = makeNoiseGate(sampleRate: Float(sampleRate))
        let voiceActivityDetector = makeVoiceActivityDetector(sampleRate: Double(sampleRate))

        // Apply noise gate
        noiseGate.process(samples: &samples)

        // DEBUG: Write audio after noise gate
        writeDebugAudio(samples: samples, sampleRate: sampleRate, stage: "2_after_noisegate")

        // Detect speech segments
        let segments = voiceActivityDetector.detectSpeechSegments(in: samples)

        if segments.isEmpty {
            Logger.shared.info("No speech detected after VAD processing (silenceThreshold: \(configurationManager.configuration.silenceThresholdDb)dB, noiseGate: \(configurationManager.configuration.noiseGateThresholdDb)dB)", component: "AudioProcessor")
            return .empty
        }

        // Extract and concatenate speech segments
        var speechSamples: [Float] = []
        for segment in segments {
            let segmentSamples = Array(samples[segment.startSample..<min(segment.endSample, samples.count)])
            speechSamples.append(contentsOf: segmentSamples)
        }

        // DEBUG: Write final processed speech
        writeDebugAudio(samples: speechSamples, sampleRate: sampleRate, stage: "3_final_speech")

        Logger.shared.debug("Extracted \(speechSamples.count) speech samples from \(samples.count) total", component: "AudioProcessor")

        // Encode to compressed format (AAC for better compatibility)
        let compressedData = try await encodeToAAC(samples: speechSamples, sampleRate: Double(sampleRate))

        Logger.shared.info("Audio processed: \(rawAudioData.count) -> \(compressedData.count) bytes", component: "AudioProcessor")

        return ProcessedAudioResult(audioData: compressedData, isEmpty: false)
    }

    private func convertToFloatSamples(_ data: Data) -> [Float] {
        let sampleCount = data.count / MemoryLayout<Int16>.size
        var samples = [Float](repeating: 0, count: sampleCount)

        data.withUnsafeBytes { (pointer: UnsafeRawBufferPointer) in
            let int16Pointer = pointer.bindMemory(to: Int16.self)
            for i in 0..<sampleCount {
                samples[i] = Float(int16Pointer[i]) / Float(Int16.max)
            }
        }

        return samples
    }

    private func encodeToAAC(samples: [Float], sampleRate: Double) async throws -> Data {
        // Convert Float samples back to Int16 PCM first
        let pcmData = convertToPCMData(samples: samples)

        // Create a temporary file for the WAV data
        let tempDir = FileManager.default.temporaryDirectory
        let wavURL = tempDir.appendingPathComponent(UUID().uuidString + ".wav")
        let aacURL = tempDir.appendingPathComponent(UUID().uuidString + ".m4a")

        defer {
            try? FileManager.default.removeItem(at: wavURL)
            try? FileManager.default.removeItem(at: aacURL)
        }

        // Write WAV file
        try writeWAVFile(pcmData: pcmData, sampleRate: Int(sampleRate), url: wavURL)

        // Convert to AAC using AVAssetWriter
        try await convertToAAC(inputURL: wavURL, outputURL: aacURL)

        // Read the compressed data
        let compressedData = try Data(contentsOf: aacURL)

        return compressedData
    }

    private func convertToPCMData(samples: [Float]) -> Data {
        var data = Data(capacity: samples.count * MemoryLayout<Int16>.size)

        for sample in samples {
            let clampedSample = max(-1, min(1, sample))
            let int16Sample = Int16(clampedSample * Float(Int16.max))

            withUnsafeBytes(of: int16Sample.littleEndian) { bytes in
                data.append(contentsOf: bytes)
            }
        }

        return data
    }

    private func writeWAVFile(pcmData: Data, sampleRate: Int, url: URL) throws {
        var header = Data()

        let channels: UInt16 = 1
        let bitsPerSample: UInt16 = 16
        let byteRate = UInt32(sampleRate * Int(channels) * Int(bitsPerSample / 8))
        let blockAlign = channels * (bitsPerSample / 8)
        let dataSize = UInt32(pcmData.count)
        let chunkSize = 36 + dataSize

        // RIFF header
        header.append("RIFF".data(using: .ascii)!)
        header.append(withUnsafeBytes(of: chunkSize.littleEndian) { Data($0) })
        header.append("WAVE".data(using: .ascii)!)

        // fmt subchunk
        header.append("fmt ".data(using: .ascii)!)
        header.append(withUnsafeBytes(of: UInt32(16).littleEndian) { Data($0) }) // Subchunk1Size
        header.append(withUnsafeBytes(of: UInt16(1).littleEndian) { Data($0) }) // AudioFormat (PCM)
        header.append(withUnsafeBytes(of: channels.littleEndian) { Data($0) })
        header.append(withUnsafeBytes(of: UInt32(sampleRate).littleEndian) { Data($0) })
        header.append(withUnsafeBytes(of: byteRate.littleEndian) { Data($0) })
        header.append(withUnsafeBytes(of: blockAlign.littleEndian) { Data($0) })
        header.append(withUnsafeBytes(of: bitsPerSample.littleEndian) { Data($0) })

        // data subchunk
        header.append("data".data(using: .ascii)!)
        header.append(withUnsafeBytes(of: dataSize.littleEndian) { Data($0) })

        var fileData = header
        fileData.append(pcmData)

        try fileData.write(to: url)
    }

    private func convertToAAC(inputURL: URL, outputURL: URL) async throws {
        let asset = AVURLAsset(url: inputURL)

        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            throw AudioProcessingError.encodingFailed("Failed to create export session")
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .m4a

        await exportSession.export()

        if let error = exportSession.error {
            throw AudioProcessingError.encodingFailed(error.localizedDescription)
        }

        guard exportSession.status == .completed else {
            throw AudioProcessingError.encodingFailed("Export failed with status: \(exportSession.status.rawValue)")
        }
    }
}

enum AudioProcessingError: LocalizedError, Sendable {
    case encodingFailed(String)

    var errorDescription: String? {
        switch self {
        case .encodingFailed(let reason):
            return "Audio encoding failed: \(reason)"
        }
    }
}
