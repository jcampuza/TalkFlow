import SwiftUI

// MARK: - ConfigurationManager Environment Key

private struct ConfigurationManagerKey: EnvironmentKey {
    static let defaultValue: ConfigurationManager? = nil
}

extension EnvironmentValues {
    var configurationManager: ConfigurationManager? {
        get { self[ConfigurationManagerKey.self] }
        set { self[ConfigurationManagerKey.self] = newValue }
    }
}

// MARK: - HistoryStorage Environment Key

private struct HistoryStorageKey: EnvironmentKey {
    static let defaultValue: HistoryStorage? = nil
}

extension EnvironmentValues {
    var historyStorage: HistoryStorage? {
        get { self[HistoryStorageKey.self] }
        set { self[HistoryStorageKey.self] = newValue }
    }
}

// MARK: - OnboardingManager Environment Key

private struct OnboardingManagerKey: EnvironmentKey {
    static let defaultValue: OnboardingManager? = nil
}

extension EnvironmentValues {
    var onboardingManager: OnboardingManager? {
        get { self[OnboardingManagerKey.self] }
        set { self[OnboardingManagerKey.self] = newValue }
    }
}

// MARK: - DictionaryManager Environment Key

private struct DictionaryManagerKey: EnvironmentKey {
    static let defaultValue: DictionaryManager? = nil
}

extension EnvironmentValues {
    var dictionaryManager: DictionaryManager? {
        get { self[DictionaryManagerKey.self] }
        set { self[DictionaryManagerKey.self] = newValue }
    }
}

// MARK: - ModelManager Environment Key

private struct ModelManagerKey: EnvironmentKey {
    static let defaultValue: ModelManager? = nil
}

extension EnvironmentValues {
    var modelManager: ModelManager? {
        get { self[ModelManagerKey.self] }
        set { self[ModelManagerKey.self] = newValue }
    }
}

// MARK: - AudioSampler Environment Key

private struct AudioSamplerKey: EnvironmentKey {
    static let defaultValue: AudioSampler? = nil
}

extension EnvironmentValues {
    var audioSampler: AudioSampler? {
        get { self[AudioSamplerKey.self] }
        set { self[AudioSamplerKey.self] = newValue }
    }
}
