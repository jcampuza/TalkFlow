import SwiftUI

struct AppearanceSettingsView: View {
    @EnvironmentObject var configurationManager: ConfigurationManager

    var body: some View {
        Form {
            Section {
                Toggle("Show Indicator When Idle", isOn: $configurationManager.configuration.indicatorVisibleWhenIdle)

                Text("When enabled, the status indicator will always be visible. When disabled, it only appears during recording and processing.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Text("Status Indicator")
            }

            Section {
                HStack {
                    Text("Indicator Position")
                    Spacer()
                    if configurationManager.configuration.indicatorPosition != nil {
                        Text("Custom")
                            .foregroundColor(.secondary)
                    } else {
                        Text("Default (Bottom Right)")
                            .foregroundColor(.secondary)
                    }
                }

                Button("Reset Position to Default") {
                    var config = configurationManager.configuration
                    config.indicatorPosition = nil
                    configurationManager.configuration = config
                }
                .disabled(configurationManager.configuration.indicatorPosition == nil)

                Text("Drag the indicator to reposition it. The position is saved automatically.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Text("Position")
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
