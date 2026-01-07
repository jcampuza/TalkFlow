import Foundation
import SwiftUI

/// Transcription mode: API (cloud) or local (on-device)
enum TranscriptionMode: String, Codable, Sendable {
    case api
    case local
}

struct AppConfiguration: Codable, Sendable {
    // Shortcut
    var triggerShortcut: ShortcutConfiguration = .rightCommand
    var minimumHoldDurationMs: Int = 300

    // Audio
    var inputDeviceUID: String? = nil
    var silenceThresholdDb: Float = -40.0
    var noiseGateThresholdDb: Float = -50.0
    var voiceIsolationEnabled: Bool = true

    // Recording limits
    var maxRecordingDurationSeconds: Int = 120
    var warningDurationSeconds: Int = 60

    // Transcription - API
    var whisperModel: String = "whisper-1"
    var language: String? = nil

    // Transcription - Local
    var transcriptionMode: TranscriptionMode = .api
    var selectedLocalModel: String? = nil
    var transcriptionLanguage: String = "auto"  // ISO code or "auto"

    // Output
    var stripPunctuation: Bool = false

    // Indicator
    var indicatorVisibleWhenIdle: Bool = false
    var indicatorPosition: CGPoint? = nil

    // Coding keys for CGPoint
    enum CodingKeys: String, CodingKey {
        case triggerShortcut
        case minimumHoldDurationMs
        case inputDeviceUID
        case silenceThresholdDb
        case noiseGateThresholdDb
        case voiceIsolationEnabled
        case maxRecordingDurationSeconds
        case warningDurationSeconds
        case whisperModel
        case language
        case transcriptionMode
        case selectedLocalModel
        case transcriptionLanguage
        case stripPunctuation
        case indicatorVisibleWhenIdle
        case indicatorPositionX
        case indicatorPositionY
    }

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        triggerShortcut = try container.decodeIfPresent(ShortcutConfiguration.self, forKey: .triggerShortcut) ?? .rightCommand
        minimumHoldDurationMs = try container.decodeIfPresent(Int.self, forKey: .minimumHoldDurationMs) ?? 300
        inputDeviceUID = try container.decodeIfPresent(String.self, forKey: .inputDeviceUID)
        silenceThresholdDb = try container.decodeIfPresent(Float.self, forKey: .silenceThresholdDb) ?? -40.0
        noiseGateThresholdDb = try container.decodeIfPresent(Float.self, forKey: .noiseGateThresholdDb) ?? -50.0
        voiceIsolationEnabled = try container.decodeIfPresent(Bool.self, forKey: .voiceIsolationEnabled) ?? true
        maxRecordingDurationSeconds = try container.decodeIfPresent(Int.self, forKey: .maxRecordingDurationSeconds) ?? 120
        warningDurationSeconds = try container.decodeIfPresent(Int.self, forKey: .warningDurationSeconds) ?? 60
        whisperModel = try container.decodeIfPresent(String.self, forKey: .whisperModel) ?? "whisper-1"
        language = try container.decodeIfPresent(String.self, forKey: .language)
        transcriptionMode = try container.decodeIfPresent(TranscriptionMode.self, forKey: .transcriptionMode) ?? .api
        selectedLocalModel = try container.decodeIfPresent(String.self, forKey: .selectedLocalModel)
        transcriptionLanguage = try container.decodeIfPresent(String.self, forKey: .transcriptionLanguage) ?? "auto"
        stripPunctuation = try container.decodeIfPresent(Bool.self, forKey: .stripPunctuation) ?? false
        indicatorVisibleWhenIdle = try container.decodeIfPresent(Bool.self, forKey: .indicatorVisibleWhenIdle) ?? false

        if let x = try container.decodeIfPresent(CGFloat.self, forKey: .indicatorPositionX),
           let y = try container.decodeIfPresent(CGFloat.self, forKey: .indicatorPositionY) {
            indicatorPosition = CGPoint(x: x, y: y)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(triggerShortcut, forKey: .triggerShortcut)
        try container.encode(minimumHoldDurationMs, forKey: .minimumHoldDurationMs)
        try container.encodeIfPresent(inputDeviceUID, forKey: .inputDeviceUID)
        try container.encode(silenceThresholdDb, forKey: .silenceThresholdDb)
        try container.encode(noiseGateThresholdDb, forKey: .noiseGateThresholdDb)
        try container.encode(voiceIsolationEnabled, forKey: .voiceIsolationEnabled)
        try container.encode(maxRecordingDurationSeconds, forKey: .maxRecordingDurationSeconds)
        try container.encode(warningDurationSeconds, forKey: .warningDurationSeconds)
        try container.encode(whisperModel, forKey: .whisperModel)
        try container.encodeIfPresent(language, forKey: .language)
        try container.encode(transcriptionMode, forKey: .transcriptionMode)
        try container.encodeIfPresent(selectedLocalModel, forKey: .selectedLocalModel)
        try container.encode(transcriptionLanguage, forKey: .transcriptionLanguage)
        try container.encode(stripPunctuation, forKey: .stripPunctuation)
        try container.encode(indicatorVisibleWhenIdle, forKey: .indicatorVisibleWhenIdle)

        if let position = indicatorPosition {
            try container.encode(position.x, forKey: .indicatorPositionX)
            try container.encode(position.y, forKey: .indicatorPositionY)
        }
    }
}

@Observable
final class ConfigurationManager: @unchecked Sendable {
    var configuration: AppConfiguration {
        didSet {
            save()
        }
    }

    private let userDefaults = UserDefaults.standard
    private let configKey = "appConfiguration"

    init() {
        configuration = ConfigurationManager.load()
    }

    private static func load() -> AppConfiguration {
        guard let data = UserDefaults.standard.data(forKey: "appConfiguration"),
              let config = try? JSONDecoder().decode(AppConfiguration.self, from: data) else {
            return AppConfiguration()
        }
        return config
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(configuration) else { return }
        userDefaults.set(data, forKey: configKey)
        Logger.shared.debug("Configuration saved", component: "Configuration")
    }

    func reset() {
        configuration = AppConfiguration()
        Logger.shared.info("Configuration reset to defaults", component: "Configuration")
    }
}
