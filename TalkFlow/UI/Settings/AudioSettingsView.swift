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
        Form {
            Section {
                Picker("Input Device", selection: $manager.configuration.inputDeviceUID) {
                    Text("System Default").tag(nil as String?)

                    ForEach(availableDevices) { device in
                        Text(device.name).tag(device.uid as String?)
                    }
                }
            } header: {
                Text("Audio Input")
            }

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Silence Threshold")
                        Spacer()
                        Text("\(Int(manager.configuration.silenceThresholdDb)) dB")
                            .foregroundColor(.secondary)
                    }

                    Slider(
                        value: $manager.configuration.silenceThresholdDb,
                        in: -60...(-20),
                        step: 1
                    )

                    Text("Lower values detect quieter speech. Default: -40 dB")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Noise Gate Threshold")
                        Spacer()
                        Text("\(Int(manager.configuration.noiseGateThresholdDb)) dB")
                            .foregroundColor(.secondary)
                    }

                    Slider(
                        value: $manager.configuration.noiseGateThresholdDb,
                        in: -70...(-30),
                        step: 1
                    )

                    Text("Reduces constant low-level background noise. Default: -50 dB")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } header: {
                Text("Audio Processing")
            }

            Section {
                HStack {
                    Text("Maximum Recording Duration")

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
            } header: {
                Text("Recording Limits")
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
