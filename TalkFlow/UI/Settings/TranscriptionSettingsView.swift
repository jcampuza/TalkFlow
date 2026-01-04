import SwiftUI

struct TranscriptionSettingsView: View {
    @EnvironmentObject var configurationManager: ConfigurationManager
    @State private var apiKey: String = ""
    @State private var isAPIKeyVisible = false
    @State private var showingSaveConfirmation = false

    private let keychainService = KeychainService()

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("OpenAI API Key")

                    HStack {
                        if isAPIKeyVisible {
                            TextField("sk-...", text: $apiKey)
                                .textFieldStyle(.roundedBorder)
                        } else {
                            SecureField("sk-...", text: $apiKey)
                                .textFieldStyle(.roundedBorder)
                        }

                        Button(action: { isAPIKeyVisible.toggle() }) {
                            Image(systemName: isAPIKeyVisible ? "eye.slash" : "eye")
                        }
                        .buttonStyle(.borderless)

                        Button("Save") {
                            saveAPIKey()
                        }
                        .disabled(apiKey.isEmpty)
                    }

                    Text("Your API key is stored securely in the macOS Keychain")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Link("Get an API key from OpenAI", destination: URL(string: "https://platform.openai.com/api-keys")!)
                        .font(.caption)
                }
            } header: {
                Text("API Configuration")
            }

            Section {
                Picker("Model", selection: $configurationManager.configuration.whisperModel) {
                    Text("whisper-1 (Default)").tag("whisper-1")
                }

                Picker("Language", selection: $configurationManager.configuration.language) {
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
            } header: {
                Text("Transcription Settings")
            }

            Section {
                Toggle("Strip Punctuation", isOn: $configurationManager.configuration.stripPunctuation)

                Text("Remove periods, commas, and other punctuation from transcriptions. Capitalization is preserved.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Text("Output Formatting")
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear {
            loadAPIKey()
        }
        .alert("API Key Saved", isPresented: $showingSaveConfirmation) {
            Button("OK", role: .cancel) {}
        }
    }

    private func loadAPIKey() {
        if let key = keychainService.getAPIKey() {
            // Show masked version
            apiKey = String(repeating: "*", count: min(key.count, 20))
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
