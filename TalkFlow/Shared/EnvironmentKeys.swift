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
