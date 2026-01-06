import SwiftUI

struct StatusIndicatorView: View {
    var stateManager: IndicatorStateManager

    @State private var pulseScale: CGFloat = 1.0
    @State private var pulseOpacity: Double = 0.6
    @State private var rotationDegrees: Double = 0

    private let size: CGFloat = 44
    private let iconSize: CGFloat = 20

    var body: some View {
        ZStack {
            // Background circle - fixed shadow, no animation dependency
            Circle()
                .fill(stateManager.state.color.opacity(0.9))
                .frame(width: size, height: size)
                .shadow(color: stateManager.state.color.opacity(0.5), radius: 8)

            // Pulse effect - only rendered during recording
            if stateManager.state == .recording {
                Circle()
                    .stroke(stateManager.state.color, lineWidth: 2)
                    .frame(width: size, height: size)
                    .scaleEffect(pulseScale)
                    .opacity(pulseOpacity)
            }

            // Icon
            Group {
                if stateManager.state == .processing {
                    // Spinning indicator for processing
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: iconSize, weight: .semibold))
                        .foregroundColor(.white)
                        .rotationEffect(.degrees(rotationDegrees))
                } else {
                    Image(systemName: stateManager.state.icon)
                        .font(.system(size: iconSize, weight: .semibold))
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
                            .frame(width: 14, height: 14)
                            .overlay(
                                Image(systemName: "exclamationmark")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundColor(.black)
                            )
                    }
                    Spacer()
                }
                .frame(width: size, height: size)
            }
        }
        .frame(width: size * 1.6, height: size * 1.6)
        .contentShape(Circle().scale(1.2))
        .onTapGesture {
            handleTap()
        }
        .onChange(of: stateManager.state) { _, newState in
            handleStateChange(newState)
        }
        .onAppear {
            handleStateChange(stateManager.state)
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

    private func handleStateChange(_ state: IndicatorState) {
        // First, immediately reset all animation states without animation
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            pulseScale = 1.0
            pulseOpacity = 0.6
            rotationDegrees = 0
        }

        // Then start appropriate animations for the new state
        if state == .recording {
            startPulseAnimation()
        } else if state == .processing {
            startRotationAnimation()
        }
    }

    private func startPulseAnimation() {
        withAnimation(
            .easeInOut(duration: 0.8)
            .repeatForever(autoreverses: true)
        ) {
            pulseScale = 1.4
            pulseOpacity = 0
        }
    }

    private func startRotationAnimation() {
        withAnimation(
            .linear(duration: 1.0)
            .repeatForever(autoreverses: false)
        ) {
            rotationDegrees = 360
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
