import SwiftUI

struct AppearanceSettingsView: View {
    @Environment(\.configurationManager) private var configurationManager

    var body: some View {
        if let manager = configurationManager {
            AppearanceSettingsContent(manager: manager)
        } else {
            Text("Configuration not available")
                .foregroundColor(DesignConstants.secondaryText)
        }
    }
}

private struct AppearanceSettingsContent: View {
    @Bindable var manager: ConfigurationManager

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Status Indicator section
            SettingsSection(title: "Status Indicator") {
                VStack(alignment: .leading, spacing: 8) {
                    SettingsRow {
                        Text("Show Indicator When Idle")
                            .foregroundColor(DesignConstants.primaryText)
                        Spacer()
                        Toggle("", isOn: $manager.configuration.indicatorVisibleWhenIdle)
                            .labelsHidden()
                    }

                    Text("When enabled, the status indicator will always be visible. When disabled, it only appears during recording and processing.")
                        .font(.caption)
                        .foregroundColor(DesignConstants.secondaryText)
                        .padding(.horizontal, 12)
                        .padding(.bottom, 10)
                }
            }

            // Position section
            SettingsSection(title: "Position") {
                VStack(spacing: 0) {
                    SettingsRow {
                        Text("Indicator Position")
                            .foregroundColor(DesignConstants.primaryText)
                        Spacer()
                        if manager.configuration.indicatorPosition != nil {
                            Text("Custom")
                                .foregroundColor(DesignConstants.secondaryText)
                        } else {
                            Text("Default (Bottom Right)")
                                .foregroundColor(DesignConstants.secondaryText)
                        }
                    }

                    SettingsDivider()

                    SettingsRow {
                        Button("Reset Position to Default") {
                            var config = manager.configuration
                            config.indicatorPosition = nil
                            manager.configuration = config
                        }
                        .disabled(manager.configuration.indicatorPosition == nil)
                    }

                    Text("Drag the indicator to reposition it. The position is saved automatically.")
                        .font(.caption)
                        .foregroundColor(DesignConstants.secondaryText)
                        .padding(.horizontal, 12)
                        .padding(.bottom, 10)
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
