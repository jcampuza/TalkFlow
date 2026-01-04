import SwiftUI

struct GeneralSettingsView: View {
    @EnvironmentObject var configurationManager: ConfigurationManager
    @State private var isRecordingShortcut = false

    var body: some View {
        Form {
            Section {
                HStack {
                    Text("Trigger Shortcut")

                    Spacer()

                    ShortcutRecorderView(
                        shortcut: $configurationManager.configuration.triggerShortcut,
                        isRecording: $isRecordingShortcut
                    )
                }

                HStack {
                    Text("Minimum Hold Duration")

                    Spacer()

                    Picker("", selection: $configurationManager.configuration.minimumHoldDurationMs) {
                        Text("100ms").tag(100)
                        Text("200ms").tag(200)
                        Text("300ms (Default)").tag(300)
                        Text("400ms").tag(400)
                        Text("500ms").tag(500)
                    }
                    .pickerStyle(.menu)
                    .frame(width: 150)
                }
            } header: {
                Text("Shortcuts")
            }

            Section {
                Toggle("Launch at Login", isOn: .constant(false))
                    .disabled(true) // TODO: Implement launch at login
            } header: {
                Text("Startup")
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

struct ShortcutRecorderView: View {
    @Binding var shortcut: ShortcutConfiguration
    @Binding var isRecording: Bool

    var body: some View {
        Button(action: { isRecording.toggle() }) {
            HStack {
                if isRecording {
                    Text("Press a key...")
                        .foregroundColor(.secondary)
                } else {
                    Text(shortcut.displayName)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isRecording ? Color.accentColor.opacity(0.2) : Color(NSColor.controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isRecording ? Color.accentColor : Color.gray.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
