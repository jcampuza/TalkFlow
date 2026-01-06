import SwiftUI
import Carbon.HIToolbox

struct GeneralSettingsView: View {
    @Environment(\.configurationManager) private var configurationManager
    @State private var isRecordingShortcut = false

    var body: some View {
        if let manager = configurationManager {
            GeneralSettingsContent(manager: manager, isRecordingShortcut: $isRecordingShortcut)
        } else {
            Text("Configuration not available")
        }
    }
}

private struct GeneralSettingsContent: View {
    @Bindable var manager: ConfigurationManager
    @Binding var isRecordingShortcut: Bool

    var body: some View {
        Form {
            Section {
                HStack {
                    Text("Trigger Shortcut")

                    Spacer()

                    ShortcutRecorderView(
                        shortcut: $manager.configuration.triggerShortcut,
                        isRecording: $isRecordingShortcut
                    )
                }

                HStack {
                    Text("Minimum Hold Duration")

                    Spacer()

                    Picker("", selection: $manager.configuration.minimumHoldDurationMs) {
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
        ShortcutRecorderButton(
            shortcut: $shortcut,
            isRecording: $isRecording
        )
        .frame(minWidth: 120)
    }
}

struct ShortcutRecorderButton: NSViewRepresentable {
    @Binding var shortcut: ShortcutConfiguration
    @Binding var isRecording: Bool

    func makeNSView(context: Context) -> NSButton {
        let button = NSButton()
        button.bezelStyle = .rounded
        button.target = context.coordinator
        button.action = #selector(Coordinator.buttonClicked)
        button.title = shortcut.displayName
        return button
    }

    func updateNSView(_ nsView: NSButton, context: Context) {
        if isRecording {
            nsView.title = "Press a key..."
            context.coordinator.startMonitoring()
        } else {
            nsView.title = shortcut.displayName
            context.coordinator.stopMonitoring()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, @unchecked Sendable {
        var parent: ShortcutRecorderButton
        var keyDownMonitor: Any?
        var flagsMonitor: Any?

        init(_ parent: ShortcutRecorderButton) {
            self.parent = parent
        }

        deinit {
            stopMonitoring()
        }

        @objc func buttonClicked() {
            parent.isRecording.toggle()
        }

        func startMonitoring() {
            guard keyDownMonitor == nil else { return }

            Logger.shared.debug("Started shortcut recording", component: "ShortcutRecorder")

            // Monitor for regular key presses
            keyDownMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                self?.handleKeyEvent(event)
                return nil // Consume the event
            }

            // Monitor for modifier key changes (for capturing modifier-only shortcuts)
            flagsMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
                self?.handleFlagsChanged(event)
                return event // Pass through flags changes
            }
        }

        func stopMonitoring() {
            if let monitor = keyDownMonitor {
                NSEvent.removeMonitor(monitor)
                keyDownMonitor = nil
            }
            if let monitor = flagsMonitor {
                NSEvent.removeMonitor(monitor)
                flagsMonitor = nil
            }
        }

        private func handleKeyEvent(_ event: NSEvent) {
            let keyCode = event.keyCode

            // Handle Escape to cancel
            if keyCode == UInt16(kVK_Escape) {
                Logger.shared.debug("Shortcut recording cancelled", component: "ShortcutRecorder")
                Task { @MainActor in
                    self.parent.isRecording = false
                }
                return
            }

            // Convert NSEvent modifiers to CGEventFlags
            let cgFlags = convertModifiers(event.modifierFlags)

            let newShortcut = ShortcutConfiguration(
                keyCode: keyCode,
                modifiers: cgFlags
            )

            Logger.shared.debug("Recorded shortcut: keyCode=\(keyCode), modifiers=\(cgFlags)", component: "ShortcutRecorder")

            Task { @MainActor in
                self.parent.shortcut = newShortcut
                self.parent.isRecording = false
            }
        }

        private func handleFlagsChanged(_ event: NSEvent) {
            let keyCode = event.keyCode

            // Only capture modifier-only shortcuts (like Right Command)
            guard isModifierKeyCode(keyCode) else { return }

            // Check if the modifier was just pressed (not released)
            let isPressed = isModifierPressed(keyCode: keyCode, flags: event.modifierFlags)

            if isPressed {
                let newShortcut = ShortcutConfiguration(
                    keyCode: keyCode,
                    modifiers: 0 // Modifier-only shortcut
                )

                Logger.shared.debug("Recorded modifier shortcut: keyCode=\(keyCode)", component: "ShortcutRecorder")

                Task { @MainActor in
                    self.parent.shortcut = newShortcut
                    self.parent.isRecording = false
                }
            }
        }

        private func convertModifiers(_ flags: NSEvent.ModifierFlags) -> UInt64 {
            var cgFlags: UInt64 = 0
            if flags.contains(.command) { cgFlags |= CGEventFlags.maskCommand.rawValue }
            if flags.contains(.shift) { cgFlags |= CGEventFlags.maskShift.rawValue }
            if flags.contains(.option) { cgFlags |= CGEventFlags.maskAlternate.rawValue }
            if flags.contains(.control) { cgFlags |= CGEventFlags.maskControl.rawValue }
            return cgFlags
        }

        private func isModifierKeyCode(_ keyCode: UInt16) -> Bool {
            switch Int(keyCode) {
            case kVK_Command, kVK_RightCommand,
                 kVK_Shift, kVK_RightShift,
                 kVK_Option, kVK_RightOption,
                 kVK_Control, kVK_RightControl,
                 kVK_CapsLock, kVK_Function:
                return true
            default:
                return false
            }
        }

        private func isModifierPressed(keyCode: UInt16, flags: NSEvent.ModifierFlags) -> Bool {
            switch Int(keyCode) {
            case kVK_Command, kVK_RightCommand:
                return flags.contains(.command)
            case kVK_Shift, kVK_RightShift:
                return flags.contains(.shift)
            case kVK_Option, kVK_RightOption:
                return flags.contains(.option)
            case kVK_Control, kVK_RightControl:
                return flags.contains(.control)
            default:
                return false
            }
        }
    }
}
