import SwiftUI

struct AppearanceSettingsView: View {
    @Environment(\.configurationManager) private var configurationManager

    var body: some View {
        if let manager = configurationManager {
            AppearanceSettingsContent(manager: manager)
        } else {
            Text("Configuration not available")
        }
    }
}

private struct AppearanceSettingsContent: View {
    @Bindable var manager: ConfigurationManager

    var body: some View {
        Form {
            Section {
                Toggle("Show Indicator When Idle", isOn: $manager.configuration.indicatorVisibleWhenIdle)

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
                    if manager.configuration.indicatorPosition != nil {
                        Text("Custom")
                            .foregroundColor(.secondary)
                    } else {
                        Text("Default (Bottom Right)")
                            .foregroundColor(.secondary)
                    }
                }

                Button("Reset Position to Default") {
                    var config = manager.configuration
                    config.indicatorPosition = nil
                    manager.configuration = config
                }
                .disabled(manager.configuration.indicatorPosition == nil)

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
