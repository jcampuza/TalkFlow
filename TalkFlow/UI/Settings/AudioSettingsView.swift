import SwiftUI

struct AudioSettingsView: View {
    @EnvironmentObject var configurationManager: ConfigurationManager
    @State private var availableDevices: [AudioDevice] = []

    var body: some View {
        Form {
            Section {
                Picker("Input Device", selection: $configurationManager.configuration.inputDeviceUID) {
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
                        Text("\(Int(configurationManager.configuration.silenceThresholdDb)) dB")
                            .foregroundColor(.secondary)
                    }

                    Slider(
                        value: $configurationManager.configuration.silenceThresholdDb,
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
                        Text("\(Int(configurationManager.configuration.noiseGateThresholdDb)) dB")
                            .foregroundColor(.secondary)
                    }

                    Slider(
                        value: $configurationManager.configuration.noiseGateThresholdDb,
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

                    Picker("", selection: $configurationManager.configuration.maxRecordingDurationSeconds) {
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
        .onAppear {
            loadDevices()
        }
    }

    private func loadDevices() {
        let captureService = AudioCaptureService(configurationManager: configurationManager)
        availableDevices = captureService.getAvailableInputDevices()
    }
}
