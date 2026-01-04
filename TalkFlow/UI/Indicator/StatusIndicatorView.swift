import SwiftUI

struct StatusIndicatorView: View {
    @ObservedObject var stateManager: IndicatorStateManager

    @State private var isPulsing = false
    @State private var isRotating = false

    private let size: CGFloat = 56

    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .fill(stateManager.state.color.opacity(0.9))
                .frame(width: size, height: size)
                .shadow(color: stateManager.state.color.opacity(0.5), radius: isPulsing ? 15 : 8)

            // Pulse effect
            if stateManager.state.shouldPulse {
                Circle()
                    .stroke(stateManager.state.color, lineWidth: 2)
                    .frame(width: size, height: size)
                    .scaleEffect(isPulsing ? 1.5 : 1.0)
                    .opacity(isPulsing ? 0 : 0.8)
            }

            // Icon
            Group {
                if stateManager.state == .processing {
                    // Spinning indicator for processing
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.white)
                        .rotationEffect(.degrees(isRotating ? 360 : 0))
                } else {
                    Image(systemName: stateManager.state.icon)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.white)
                }
            }

            // Warning badge
            if stateManager.state == .warning {
                VStack {
                    HStack {
                        Spacer()
                        Circle()
                            .fill(Color.yellow)
                            .frame(width: 16, height: 16)
                            .overlay(
                                Image(systemName: "exclamationmark")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.black)
                            )
                    }
                    Spacer()
                }
                .frame(width: size, height: size)
            }
        }
        .onTapGesture {
            handleTap()
        }
        .onChange(of: stateManager.state) { _, newState in
            updateAnimations(for: newState)
        }
        .onAppear {
            updateAnimations(for: stateManager.state)
        }
        .help(stateManager.state == .permissionRequired ? "Click to open Accessibility settings" : "")
    }

    private func handleTap() {
        if stateManager.state == .permissionRequired {
            openAccessibilitySettings()
        }
    }

    private func openAccessibilitySettings() {
        // Use the shell command approach which works reliably on all macOS versions
        let script = """
            tell application "System Settings"
                activate
                reveal anchor "Privacy_Accessibility" of pane id "com.apple.settings.PrivacySecurity"
            end tell
            """

        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: script) {
            scriptObject.executeAndReturnError(&error)

            if error != nil {
                // Fallback: just open System Settings
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:")!)
            }
        }
    }

    private func updateAnimations(for state: IndicatorState) {
        // Pulse animation
        if state.shouldPulse {
            withAnimation(
                .easeInOut(duration: state.pulseSpeed)
                .repeatForever(autoreverses: true)
            ) {
                isPulsing = true
            }
        } else {
            isPulsing = false
        }

        // Rotation animation for processing
        if state == .processing {
            withAnimation(
                .linear(duration: 1.0)
                .repeatForever(autoreverses: false)
            ) {
                isRotating = true
            }
        } else {
            isRotating = false
        }
    }
}

extension IndicatorState: Hashable {
    func hash(into hasher: inout Hasher) {
        switch self {
        case .idle:
            hasher.combine(0)
        case .recording:
            hasher.combine(1)
        case .warning:
            hasher.combine(2)
        case .processing:
            hasher.combine(3)
        case .success:
            hasher.combine(4)
        case .error(let message):
            hasher.combine(5)
            hasher.combine(message)
        case .noSpeech:
            hasher.combine(6)
        case .permissionRequired:
            hasher.combine(7)
        }
    }
}
