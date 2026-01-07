import SwiftUI

struct TranscriptionSettingsView: View {
    @Environment(\.configurationManager) private var configurationManager
    @State private var apiKey: String = ""
    @State private var isAPIKeyVisible = false
    @State private var showingSaveConfirmation = false

    private let keychainService = KeychainService()

    var body: some View {
        if let manager = configurationManager {
            TranscriptionSettingsContent(
                manager: manager,
                apiKey: $apiKey,
                isAPIKeyVisible: $isAPIKeyVisible,
                showingSaveConfirmation: $showingSaveConfirmation,
                keychainService: keychainService
            )
            .onAppear {
                loadAPIKey()
            }
        } else {
            Text("Configuration not available")
                .foregroundColor(DesignConstants.secondaryText)
        }
    }

    private func loadAPIKey() {
        if let key = keychainService.getAPIKey() {
            // Show masked version
            apiKey = String(repeating: "*", count: min(key.count, 20))
        }
    }
}

private struct TranscriptionSettingsContent: View {
    @Bindable var manager: ConfigurationManager
    @Binding var apiKey: String
    @Binding var isAPIKeyVisible: Bool
    @Binding var showingSaveConfirmation: Bool
    let keychainService: KeychainService

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // API Configuration section
            SettingsSection(title: "API Configuration") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("OpenAI API Key")
                        .foregroundColor(DesignConstants.primaryText)

                    HStack {
                        if isAPIKeyVisible {
                            TextField("sk-...", text: $apiKey)
                                .textFieldStyle(.plain)
                                .padding(8)
                                .background(DesignConstants.searchBarBackground)
                                .cornerRadius(6)
                                .foregroundColor(DesignConstants.primaryText)
                        } else {
                            SecureField("sk-...", text: $apiKey)
                                .textFieldStyle(.plain)
                                .padding(8)
                                .background(DesignConstants.searchBarBackground)
                                .cornerRadius(6)
                                .foregroundColor(DesignConstants.primaryText)
                        }

                        Button(action: { isAPIKeyVisible.toggle() }) {
                            Image(systemName: isAPIKeyVisible ? "eye.slash" : "eye")
                                .foregroundColor(DesignConstants.secondaryText)
                        }
                        .buttonStyle(.borderless)

                        Button("Save") {
                            saveAPIKey()
                        }
                        .disabled(apiKey.isEmpty)
                    }

                    Text("Your API key is stored securely in the macOS Keychain")
                        .font(.caption)
                        .foregroundColor(DesignConstants.secondaryText)

                    Link("Get an API key from OpenAI", destination: URL(string: "https://platform.openai.com/api-keys")!)
                        .font(.caption)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }

            // Transcription Settings section
            SettingsSection(title: "Transcription Settings") {
                VStack(spacing: 0) {
                    SettingsRow {
                        Text("Model")
                            .foregroundColor(DesignConstants.primaryText)
                        Spacer()
                        Picker("", selection: $manager.configuration.whisperModel) {
                            Text("whisper-1 (Default)").tag("whisper-1")
                        }
                        .pickerStyle(.menu)
                        .frame(width: 180)
                    }

                    SettingsDivider()

                    SettingsRow {
                        Text("Language")
                            .foregroundColor(DesignConstants.primaryText)
                        Spacer()
                        Picker("", selection: $manager.configuration.language) {
                            Text("Auto-detect").tag(nil as String?)
                            Divider()
                            Text("English").tag("en" as String?)
                            Text("Spanish").tag("es" as String?)
                            Text("French").tag("fr" as String?)
                            Text("German").tag("de" as String?)
                            Text("Italian").tag("it" as String?)
                            Text("Portuguese").tag("pt" as String?)
                            Text("Japanese").tag("ja" as String?)
                            Text("Chinese").tag("zh" as String?)
                            Text("Korean").tag("ko" as String?)
                            Text("Russian").tag("ru" as String?)
                            Text("Arabic").tag("ar" as String?)
                        }
                        .pickerStyle(.menu)
                        .frame(width: 180)
                    }
                }
            }

            // Output Formatting section
            SettingsSection(title: "Output Formatting") {
                VStack(alignment: .leading, spacing: 8) {
                    SettingsRow {
                        Text("Strip Punctuation")
                            .foregroundColor(DesignConstants.primaryText)
                        Spacer()
                        Toggle("", isOn: $manager.configuration.stripPunctuation)
                            .labelsHidden()
                    }

                    Text("Remove periods, commas, and other punctuation from transcriptions. Capitalization is preserved.")
                        .font(.caption)
                        .foregroundColor(DesignConstants.secondaryText)
                        .padding(.horizontal, 12)
                        .padding(.bottom, 10)
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .alert("API Key Saved", isPresented: $showingSaveConfirmation) {
            Button("OK", role: .cancel) {}
        }
    }

    private func saveAPIKey() {
        // Don't save if it's just the masked version
        if apiKey.allSatisfy({ $0 == "*" }) {
            return
        }

        keychainService.setAPIKey(apiKey)
        showingSaveConfirmation = true

        // Mask the key after saving
        apiKey = String(repeating: "*", count: min(apiKey.count, 20))
    }
}
