import SwiftUI

struct TranscriptionSettingsView: View {
    @Environment(\.configurationManager) private var configurationManager
    @Environment(\.modelManager) private var modelManager
    @State private var apiKey: String = ""
    @State private var isAPIKeyVisible = false
    @State private var showingSaveConfirmation = false
    @State private var hasStoredKey = false
    @State private var hasLoadedActualKey = false

    private let keychainService = KeychainService()

    var body: some View {
        if let manager = configurationManager, let models = modelManager {
            TranscriptionSettingsContent(
                manager: manager,
                modelManager: models,
                apiKey: $apiKey,
                isAPIKeyVisible: $isAPIKeyVisible,
                showingSaveConfirmation: $showingSaveConfirmation,
                hasStoredKey: $hasStoredKey,
                hasLoadedActualKey: $hasLoadedActualKey,
                keychainService: keychainService
            )
            .onAppear {
                checkForStoredKey()
            }
        } else {
            Text("Configuration not available")
                .foregroundColor(DesignConstants.secondaryText)
        }
    }

    /// Check if an API key exists without triggering Keychain permission dialog
    private func checkForStoredKey() {
        hasStoredKey = keychainService.hasAPIKeyWithoutFetch()
        if hasStoredKey && !hasLoadedActualKey {
            // Show placeholder asterisks without actually loading the key
            apiKey = String(repeating: "•", count: 20)
        }
    }
}

private struct TranscriptionSettingsContent: View {
    @Bindable var manager: ConfigurationManager
    @Bindable var modelManager: ModelManager
    @Binding var apiKey: String
    @Binding var isAPIKeyVisible: Bool
    @Binding var showingSaveConfirmation: Bool
    @Binding var hasStoredKey: Bool
    @Binding var hasLoadedActualKey: Bool
    let keychainService: KeychainService

    @State private var showDownloadSuccessAlert = false
    @State private var showDownloadErrorAlert = false
    @State private var downloadErrorMessage = ""
    @State private var downloadedModelName = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Transcription Source section
            SettingsSection(title: "Transcription Source") {
                VStack(spacing: 0) {
                    // Local Model Toggle
                    SettingsRow {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Use Local Model")
                                .foregroundColor(DesignConstants.primaryText)
                            Text("Transcribe on-device without sending audio to the cloud")
                                .font(.caption)
                                .foregroundColor(DesignConstants.secondaryText)
                        }
                        Spacer()
                        Toggle("", isOn: localModeBinding)
                            .labelsHidden()
                            .tint(DesignConstants.accentColor)
                            .disabled(modelManager.isDownloading)
                    }

                    // Show all models when local mode is on
                    if manager.configuration.transcriptionMode == .local {
                        SettingsDivider()
                        localModelSection
                    }
                }
            }

            // API Configuration section (shown when not in local mode)
            if manager.configuration.transcriptionMode == .api {
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

                            Button(action: { toggleAPIKeyVisibility() }) {
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
            }

            // Transcription Settings section
            SettingsSection(title: "Transcription Settings") {
                VStack(spacing: 0) {
                    if manager.configuration.transcriptionMode == .api {
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
                    }

                    SettingsRow {
                        Text("Language")
                            .foregroundColor(DesignConstants.primaryText)
                        Spacer()
                        Picker("", selection: languageBinding) {
                            Text("Auto-detect").tag("auto")
                            Divider()
                            Text("English").tag("en")
                            Text("Spanish").tag("es")
                            Text("French").tag("fr")
                            Text("German").tag("de")
                            Text("Italian").tag("it")
                            Text("Portuguese").tag("pt")
                            Text("Japanese").tag("ja")
                            Text("Chinese").tag("zh")
                            Text("Korean").tag("ko")
                            Text("Russian").tag("ru")
                            Text("Arabic").tag("ar")
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
                            .tint(DesignConstants.accentColor)
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
        .alert("Model Downloaded", isPresented: $showDownloadSuccessAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("\(downloadedModelName) has been downloaded successfully and is now ready to use.")
        }
        .alert("Download Failed", isPresented: $showDownloadErrorAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(downloadErrorMessage)
        }
    }

    // MARK: - Local Model Section

    @ViewBuilder
    private var localModelSection: some View {
        VStack(spacing: 0) {
            // If downloading, show progress (blocks interaction)
            if modelManager.isDownloading {
                downloadProgressView
            } else {
                // Always show all models
                ForEach(LocalWhisperModel.allModels) { model in
                    if model.id != LocalWhisperModel.allModels.first?.id {
                        SettingsDivider()
                    }
                    modelRowView(model: model)
                }
            }
        }
    }

    @ViewBuilder
    private var downloadProgressView: some View {
        SettingsRow {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Downloading model...")
                        .foregroundColor(DesignConstants.primaryText)
                    Spacer()
                    Button("Cancel") {
                        modelManager.cancelDownload()
                    }
                    .buttonStyle(.borderless)
                    .foregroundColor(.red)
                }

                ProgressView(value: modelManager.downloadProgress)
                    .progressViewStyle(.linear)

                Text("\(Int(modelManager.downloadProgress * 100))% complete")
                    .font(.caption)
                    .foregroundColor(DesignConstants.secondaryText)
            }
        }
    }

    @ViewBuilder
    private func modelRowView(model: LocalWhisperModel) -> some View {
        let isDownloaded = modelManager.downloadedModels.contains(model.id)
        let isActive = manager.configuration.selectedLocalModel == model.id

        SettingsRow {
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    // Green checkmark for active, grey for downloaded but not active
                    if isActive {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    } else if isDownloaded {
                        Image(systemName: "checkmark.circle")
                            .foregroundColor(DesignConstants.secondaryText)
                    }

                    Text(model.displayName)
                        .foregroundColor(DesignConstants.primaryText)
                    Text(model.sizeDescription)
                        .font(.caption)
                        .foregroundColor(DesignConstants.secondaryText)
                }
                Text(model.qualityDescription)
                    .font(.caption)
                    .foregroundColor(DesignConstants.secondaryText)
            }

            Spacer()

            HStack(spacing: 8) {
                // Active model: just Delete
                // Downloaded but not active: "Use This" + Delete
                // Not downloaded: "Download"
                if isActive {
                    // Active model only has delete
                    Button("Delete") {
                        deleteModel(model.id)
                    }
                    .buttonStyle(.bordered)
                    .foregroundColor(.red)
                } else if isDownloaded {
                    Button("Use This") {
                        manager.configuration.selectedLocalModel = model.id
                    }
                    .buttonStyle(.bordered)

                    Button("Delete") {
                        deleteModel(model.id)
                    }
                    .buttonStyle(.bordered)
                    .foregroundColor(.red)
                } else {
                    Button("Download") {
                        downloadModel(model.id)
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    // MARK: - Bindings

    private var localModeBinding: Binding<Bool> {
        Binding(
            get: { manager.configuration.transcriptionMode == .local },
            set: { newValue in
                if newValue {
                    // Switch to local mode - if we have a downloaded model, select it
                    manager.configuration.transcriptionMode = .local
                    // Auto-select a downloaded model if none is selected
                    if manager.configuration.selectedLocalModel == nil ||
                       !modelManager.downloadedModels.contains(manager.configuration.selectedLocalModel ?? "") {
                        // Select the first downloaded model, or leave nil to prompt download
                        manager.configuration.selectedLocalModel = modelManager.downloadedModels.first
                    }
                } else {
                    manager.configuration.transcriptionMode = .api
                }
            }
        )
    }

    private var languageBinding: Binding<String> {
        Binding(
            get: {
                if manager.configuration.transcriptionMode == .local {
                    return manager.configuration.transcriptionLanguage
                } else {
                    return manager.configuration.language ?? "auto"
                }
            },
            set: { newValue in
                if manager.configuration.transcriptionMode == .local {
                    manager.configuration.transcriptionLanguage = newValue
                } else {
                    manager.configuration.language = newValue == "auto" ? nil : newValue
                }
            }
        )
    }

    // MARK: - Actions

    private func toggleAPIKeyVisibility() {
        if !isAPIKeyVisible {
            // User wants to reveal the key - load from Keychain if not already loaded
            if hasStoredKey && !hasLoadedActualKey {
                if let key = keychainService.getAPIKey() {
                    apiKey = key
                    hasLoadedActualKey = true
                }
            }
        }
        isAPIKeyVisible.toggle()
    }

    private func saveAPIKey() {
        // Don't save if it's just placeholder dots
        if apiKey.allSatisfy({ $0 == "•" || $0 == "*" }) {
            return
        }

        keychainService.setAPIKey(apiKey)
        showingSaveConfirmation = true
        hasStoredKey = true
        hasLoadedActualKey = true
        // Mask the key after saving
        apiKey = String(repeating: "•", count: min(apiKey.count, 20))
        isAPIKeyVisible = false
    }

    private func downloadModel(_ modelId: String) {
        Task {
            do {
                Logger.shared.info("Starting download of model: \(modelId)", component: "TranscriptionSettings")
                try await modelManager.downloadModel(modelId) { progress in
                    // Progress is automatically updated via @Observable
                    Logger.shared.debug("Download progress: \(Int(progress * 100))%", component: "TranscriptionSettings")
                }
                // After successful download, select the model
                await MainActor.run {
                    Logger.shared.info("Download completed successfully for: \(modelId)", component: "TranscriptionSettings")
                    manager.configuration.selectedLocalModel = modelId

                    // Show success alert
                    if let model = LocalWhisperModel.model(for: modelId) {
                        downloadedModelName = model.displayName
                    } else {
                        downloadedModelName = modelId
                    }
                    showDownloadSuccessAlert = true
                }
            } catch {
                Logger.shared.error("Model download failed: \(error)", component: "TranscriptionSettings")
                await MainActor.run {
                    downloadErrorMessage = error.localizedDescription
                    showDownloadErrorAlert = true
                    // Reset state
                    modelManager.resetDownloadState()
                }
            }
        }
    }

    private func deleteModel(_ modelId: String) {
        Task {
            do {
                try await modelManager.deleteModel(modelId)
                await MainActor.run {
                    if manager.configuration.selectedLocalModel == modelId {
                        manager.configuration.selectedLocalModel = nil
                        // If no other models are downloaded, switch to API mode
                        if modelManager.downloadedModels.isEmpty {
                            manager.configuration.transcriptionMode = .api
                        } else {
                            // Select another downloaded model
                            manager.configuration.selectedLocalModel = modelManager.downloadedModels.first
                        }
                    }
                }
            } catch {
                Logger.shared.error("Model deletion failed: \(error)", component: "TranscriptionSettings")
            }
        }
    }
}
