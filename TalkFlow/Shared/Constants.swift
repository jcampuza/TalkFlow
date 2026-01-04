import Foundation

enum Constants {
    enum App {
        static let bundleIdentifier = "com.josephcampuzano.TalkFlow"
        static let name = "TalkFlow"
    }

    enum Recording {
        static let defaultMaxDurationSeconds = 120
        static let defaultWarningDurationSeconds = 60
        static let defaultMinimumHoldDurationMs = 300
    }

    enum Audio {
        static let defaultSilenceThresholdDb: Float = -40.0
        static let defaultNoiseGateThresholdDb: Float = -50.0
        static let sampleRate: Double = 44100
        static let bufferSize: UInt32 = 4096
    }

    enum Indicator {
        static let size: CGFloat = 56
        static let padding: CGFloat = 40
        static let transientDuration: TimeInterval = 2.5
    }

    enum API {
        static let openAIBaseURL = "https://api.openai.com/v1"
        static let defaultWhisperModel = "whisper-1"
        static let maxRetries = 3
    }

    enum Storage {
        static let databaseName = "transcriptions.sqlite"
    }

    enum Logging {
        static let maxLogAgeDays = 7
    }
}
