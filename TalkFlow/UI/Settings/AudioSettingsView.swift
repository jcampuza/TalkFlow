import SwiftUI

struct AudioSettingsView: View {
    @Environment(\.configurationManager) private var configurationManager
    @State private var availableDevices: [AudioDevice] = []

    var body: some View {
        if let manager = configurationManager {
            AudioSettingsContent(manager: manager, availableDevices: $availableDevices)
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

            // Audio Processing section
            SettingsSection(title: "Audio Processing") {
                VStack(spacing: 0) {
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
}
