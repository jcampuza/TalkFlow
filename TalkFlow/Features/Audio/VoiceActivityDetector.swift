import Foundation
import Accelerate

struct SpeechSegment {
    let startSample: Int
    let endSample: Int
}

final class VoiceActivityDetector {
    private let sampleRate: Double
    private let frameSize: Int
    private let hopSize: Int
    private let silenceThresholdDb: Float
    private let minSpeechDurationMs: Double
    private let paddingMs: Double

    init(
        sampleRate: Double = 44100,
        frameSize: Int = 2048,
        hopSize: Int = 512,
        silenceThresholdDb: Float = -40,
        minSpeechDurationMs: Double = 100,
        paddingMs: Double = 200
    ) {
        self.sampleRate = sampleRate
        self.frameSize = frameSize
        self.hopSize = hopSize
        self.silenceThresholdDb = silenceThresholdDb
        self.minSpeechDurationMs = minSpeechDurationMs
        self.paddingMs = paddingMs
    }

    func detectSpeechSegments(in samples: [Float]) -> [SpeechSegment] {
        guard !samples.isEmpty else { return [] }

        // Calculate energy for each frame
        var frameEnergies: [(index: Int, energy: Float)] = []

        var frameStart = 0
        while frameStart + frameSize <= samples.count {
            let frame = Array(samples[frameStart..<(frameStart + frameSize)])
            let energy = calculateEnergyDb(frame: frame)
            frameEnergies.append((index: frameStart, energy: energy))
            frameStart += hopSize
        }

        // Identify frames above threshold
        var speechFrames: [Bool] = frameEnergies.map { $0.energy > silenceThresholdDb }

        // Apply minimum duration filter
        let minFrames = Int((minSpeechDurationMs / 1000.0) * sampleRate / Double(hopSize))
        speechFrames = filterShortSegments(speechFrames, minLength: minFrames)

        // Fill small gaps
        let maxGapFrames = Int((100.0 / 1000.0) * sampleRate / Double(hopSize)) // 100ms gaps
        speechFrames = fillSmallGaps(speechFrames, maxGap: maxGapFrames)

        // Convert to segments with padding
        let paddingSamples = Int((paddingMs / 1000.0) * sampleRate)
        var segments: [SpeechSegment] = []
        var inSpeech = false
        var segmentStart = 0

        for (index, isSpeech) in speechFrames.enumerated() {
            let samplePosition = frameEnergies[index].index

            if isSpeech && !inSpeech {
                // Start of speech
                segmentStart = max(0, samplePosition - paddingSamples)
                inSpeech = true
            } else if !isSpeech && inSpeech {
                // End of speech
                let segmentEnd = min(samples.count, samplePosition + paddingSamples)
                segments.append(SpeechSegment(startSample: segmentStart, endSample: segmentEnd))
                inSpeech = false
            }
        }

        // Handle case where speech continues to end
        if inSpeech {
            segments.append(SpeechSegment(startSample: segmentStart, endSample: samples.count))
        }

        // Merge overlapping segments
        segments = mergeOverlappingSegments(segments)

        Logger.shared.debug("VAD detected \(segments.count) speech segments", component: "VAD")

        return segments
    }

    private func calculateEnergyDb(frame: [Float]) -> Float {
        var sum: Float = 0
        vDSP_svesq(frame, 1, &sum, vDSP_Length(frame.count))
        let rms = sqrt(sum / Float(frame.count))
        return 20 * log10(max(rms, 1e-10))
    }

    private func filterShortSegments(_ frames: [Bool], minLength: Int) -> [Bool] {
        var result = frames
        var i = 0

        while i < frames.count {
            if frames[i] {
                // Find end of this segment
                var j = i
                while j < frames.count && frames[j] {
                    j += 1
                }

                // Check if segment is too short
                if j - i < minLength {
                    for k in i..<j {
                        result[k] = false
                    }
                }

                i = j
            } else {
                i += 1
            }
        }

        return result
    }

    private func fillSmallGaps(_ frames: [Bool], maxGap: Int) -> [Bool] {
        var result = frames
        var i = 0

        while i < frames.count {
            if !frames[i] {
                // Find end of this gap
                var j = i
                while j < frames.count && !frames[j] {
                    j += 1
                }

                // Check if gap is small and surrounded by speech
                if j - i <= maxGap && i > 0 && j < frames.count && frames[i - 1] && frames[j] {
                    for k in i..<j {
                        result[k] = true
                    }
                }

                i = j
            } else {
                i += 1
            }
        }

        return result
    }

    private func mergeOverlappingSegments(_ segments: [SpeechSegment]) -> [SpeechSegment] {
        guard !segments.isEmpty else { return [] }

        var merged: [SpeechSegment] = []
        var current = segments[0]

        for i in 1..<segments.count {
            let next = segments[i]

            if next.startSample <= current.endSample {
                // Overlapping, merge
                current = SpeechSegment(
                    startSample: current.startSample,
                    endSample: max(current.endSample, next.endSample)
                )
            } else {
                merged.append(current)
                current = next
            }
        }

        merged.append(current)
        return merged
    }

    func containsSpeech(in samples: [Float]) -> Bool {
        let segments = detectSpeechSegments(in: samples)
        return !segments.isEmpty
    }
}
