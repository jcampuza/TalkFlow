import SwiftUI

struct AudioSettingsView: View {
    @Environment(\.configurationManager) private var configurationManager
    @Environment(\.audioSampler) private var audioSampler
    @State private var availableDevices: [AudioDevice] = []

    var body: some View {
        if let manager = configurationManager, let sampler = audioSampler {
            AudioSettingsContent(manager: manager, audioSampler: sampler, availableDevices: $availableDevices)
                .onAppear {
                    loadDevices(manager: manager)
                }
        } else {
            Text("Configuration not available")
                .foregroundColor(DesignConstants.secondaryText)
        }
    }

    private func loadDevices(manager: ConfigurationManager) {
        let captureService = AudioCaptureService(configurationManager: manager)
        availableDevices = captureService.getAvailableInputDevices()
    }
}

private struct AudioSettingsContent: View {
    @Bindable var manager: ConfigurationManager
    @Bindable var audioSampler: AudioSampler
    @Binding var availableDevices: [AudioDevice]

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Audio Input section
            SettingsSection(title: "Audio Input") {
                SettingsRow {
                    Text("Input Device")
                        .foregroundColor(DesignConstants.primaryText)
                    Spacer()
                    Picker("", selection: $manager.configuration.inputDeviceUID) {
                        Text("System Default").tag(nil as String?)

                        ForEach(availableDevices) { device in
                            Text(device.name).tag(device.uid as String?)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 200)
                }
            }

            // Test Microphone section
            SettingsSection(title: "Test Microphone") {
                VStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Record a short clip to test your microphone and hear how it sounds.")
                            .font(.callout)
                            .foregroundColor(DesignConstants.secondaryText)

                        HStack(spacing: 12) {
                            // Record/Stop button
                            if audioSampler.state == .recording {
                                Button(action: { audioSampler.stopRecording() }) {
                                    HStack {
                                        Image(systemName: "stop.fill")
                                        Text("Stop")
                                    }
                                    .frame(width: 100)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.red)
                            } else {
                                Button(action: { startRecording() }) {
                                    HStack {
                                        Image(systemName: "mic.fill")
                                        Text("Record")
                                    }
                                    .frame(width: 100)
                                }
                                .buttonStyle(.bordered)
                                .disabled(audioSampler.state == .playing)
                            }

                            // Play button
                            if audioSampler.hasRecording {
                                if audioSampler.state == .playing {
                                    Button(action: { audioSampler.stopPlayback() }) {
                                        HStack {
                                            Image(systemName: "stop.fill")
                                            Text("Stop")
                                        }
                                        .frame(width: 100)
                                    }
                                    .buttonStyle(.bordered)
                                } else {
                                    Button(action: { audioSampler.play() }) {
                                        HStack {
                                            Image(systemName: "play.fill")
                                            Text("Play")
                                        }
                                        .frame(width: 100)
                                    }
                                    .buttonStyle(.bordered)
                                    .disabled(audioSampler.state == .recording)
                                }
                            }

                            // Clear button
                            if audioSampler.hasRecording && audioSampler.state == .idle {
                                Button(action: { audioSampler.clearRecording() }) {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(.borderless)
                                .foregroundColor(DesignConstants.secondaryText)
                            }

                            Spacer()
                        }

                        // Recording indicator
                        if audioSampler.state == .recording {
                            HStack(spacing: 8) {
                                // Audio level meter
                                GeometryReader { geometry in
                                    ZStack(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 2)
                                            .fill(DesignConstants.searchBarBackground)
                                        RoundedRectangle(cornerRadius: 2)
                                            .fill(Color.green)
                                            .frame(width: geometry.size.width * CGFloat(audioSampler.audioLevel))
                                    }
                                }
                                .frame(height: 8)

                                Text(String(format: "%.1fs / 10s", audioSampler.recordingDuration))
                                    .font(.caption)
                                    .foregroundColor(DesignConstants.secondaryText)
                                    .frame(width: 70, alignment: .trailing)
                            }
                        }

                        // Playback indicator
                        if audioSampler.state == .playing {
                            HStack {
                                Image(systemName: "speaker.wave.2.fill")
                                    .foregroundColor(.blue)
                                Text("Playing...")
                                    .font(.caption)
                                    .foregroundColor(DesignConstants.secondaryText)
                            }
                        }

                        // Ready to play indicator
                        if audioSampler.hasRecording && audioSampler.state == .idle {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("Recording ready - click Play to listen")
                                    .font(.caption)
                                    .foregroundColor(DesignConstants.secondaryText)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                }
            }

            // Audio Processing section
            SettingsSection(title: "Audio Processing") {
                VStack(spacing: 0) {
                    SettingsRow {
                        Toggle(isOn: $manager.configuration.voiceIsolationEnabled) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Voice Isolation")
                                    .foregroundColor(DesignConstants.primaryText)
                                Text("Uses Apple's voice processing to reduce background noise and isolate speech")
                                    .font(.caption)
                                    .foregroundColor(DesignConstants.secondaryText)
                            }
                        }
                        .toggleStyle(.switch)
                    }

                    SettingsDivider()

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Silence Threshold")
                                .foregroundColor(DesignConstants.primaryText)
                            Spacer()
                            Text("\(Int(manager.configuration.silenceThresholdDb)) dB")
                                .foregroundColor(DesignConstants.secondaryText)
                        }

                        Slider(
                            value: $manager.configuration.silenceThresholdDb,
                            in: -60...(-20),
                            step: 1
                        )

                        Text("Lower values detect quieter speech. Default: -40 dB")
                            .font(.caption)
                            .foregroundColor(DesignConstants.secondaryText)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)

                    SettingsDivider()

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Noise Gate Threshold")
                                .foregroundColor(DesignConstants.primaryText)
                            Spacer()
                            Text("\(Int(manager.configuration.noiseGateThresholdDb)) dB")
                                .foregroundColor(DesignConstants.secondaryText)
                        }

                        Slider(
                            value: $manager.configuration.noiseGateThresholdDb,
                            in: -70...(-30),
                            step: 1
                        )

                        Text("Reduces constant low-level background noise. Default: -50 dB")
                            .font(.caption)
                            .foregroundColor(DesignConstants.secondaryText)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                }
            }

            // Recording Limits section
            SettingsSection(title: "Recording Limits") {
                SettingsRow {
                    Text("Maximum Recording Duration")
                        .foregroundColor(DesignConstants.primaryText)
                    Spacer()
                    Picker("", selection: $manager.configuration.maxRecordingDurationSeconds) {
                        Text("1 minute").tag(60)
                        Text("2 minutes (Default)").tag(120)
                        Text("3 minutes").tag(180)
                        Text("5 minutes").tag(300)
                    }
                    .pickerStyle(.menu)
                    .frame(width: 180)
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func startRecording() {
        do {
            try audioSampler.startRecording()
        } catch {
            Logger.shared.error("Failed to start audio sample recording: \(error)", component: "AudioSettings")
        }
    }
}
