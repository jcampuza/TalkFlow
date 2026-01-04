import Foundation
import Accelerate

final class NoiseGate {
    private let thresholdDb: Float
    private let attackMs: Float
    private let releaseMs: Float
    private let sampleRate: Float

    private var envelope: Float = 0
    private var isOpen = false

    init(thresholdDb: Float = -50, attackMs: Float = 5, releaseMs: Float = 50, sampleRate: Float = 44100) {
        self.thresholdDb = thresholdDb
        self.attackMs = attackMs
        self.releaseMs = releaseMs
        self.sampleRate = sampleRate
    }

    func process(samples: inout [Float]) {
        let attackCoeff = exp(-1.0 / (attackMs * sampleRate / 1000))
        let releaseCoeff = exp(-1.0 / (releaseMs * sampleRate / 1000))
        let thresholdLinear = pow(10, thresholdDb / 20)

        for i in 0..<samples.count {
            let inputAbs = abs(samples[i])

            // Update envelope follower
            if inputAbs > envelope {
                envelope = attackCoeff * envelope + (1 - attackCoeff) * inputAbs
            } else {
                envelope = releaseCoeff * envelope + (1 - releaseCoeff) * inputAbs
            }

            // Apply gate
            if envelope < thresholdLinear {
                // Below threshold, attenuate
                samples[i] *= envelope / max(thresholdLinear, 0.00001)
            }
        }
    }

    func reset() {
        envelope = 0
        isOpen = false
    }
}
