import SwiftUI

struct OnboardingView: View {
    var onboardingManager: OnboardingManager
    @State private var isAnimating = false

    var body: some View {
        VStack(spacing: 0) {
            // Progress indicator
            ProgressIndicatorView(
                currentStep: onboardingManager.currentStep,
                steps: OnboardingManager.OnboardingStep.allCases
            )
            .padding(.top, 24)
            .padding(.horizontal, 40)

            Spacer()

            // Content based on current step
            stepContent
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
                .id(onboardingManager.currentStep)

            Spacer()

            // Navigation buttons
            navigationButtons
                .padding(.horizontal, 40)
                .padding(.bottom, 32)
        }
        .frame(width: 550, height: 450)
        .background(Color.white)
        .environment(\.colorScheme, .light)
        .tint(DesignConstants.accentColor)
        .animation(.easeInOut(duration: 0.3), value: onboardingManager.currentStep)
    }

    @ViewBuilder
    private var stepContent: some View {
        switch onboardingManager.currentStep {
        case .welcome:
            WelcomeStepView(isAnimating: $isAnimating)
        case .microphonePermission:
            MicrophonePermissionStepView(
                hasPermission: onboardingManager.hasMicrophonePermission,
                onRequestPermission: onboardingManager.requestMicrophonePermission
            )
        case .accessibilityPermission:
            AccessibilityPermissionStepView(
                hasPermission: onboardingManager.hasAccessibilityPermission,
                onRequestPermission: onboardingManager.requestAccessibilityPermission,
                onOpenSettings: onboardingManager.openAccessibilitySettings
            )
        case .complete:
            CompleteStepView()
        }
    }

    @ViewBuilder
    private var navigationButtons: some View {
        HStack {
            // Back/Skip button
            if onboardingManager.currentStep != .welcome && onboardingManager.currentStep != .complete {
                Button("Skip") {
                    withAnimation {
                        onboardingManager.skipCurrentStep()
                    }
                }
                .buttonStyle(.plain)
                .foregroundColor(DesignConstants.secondaryText)
            }

            Spacer()

            // Continue/Done button
            Button(action: {
                withAnimation {
                    if onboardingManager.currentStep == .complete {
                        onboardingManager.completeOnboarding()
                    } else {
                        onboardingManager.nextStep()
                    }
                }
            }) {
                Text(continueButtonTitle)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(continueButtonColor)
                    .cornerRadius(8)
            }
            .buttonStyle(.plain)
            .disabled(shouldDisableContinue)
            .opacity(shouldDisableContinue ? 0.5 : 1.0)
        }
    }

    private var continueButtonTitle: String {
        switch onboardingManager.currentStep {
        case .welcome:
            return "Get Started"
        case .microphonePermission, .accessibilityPermission:
            return "Continue"
        case .complete:
            return "Done"
        }
    }

    private var continueButtonColor: Color {
        // All buttons use accent color
        return DesignConstants.accentColor
    }

    private var shouldDisableContinue: Bool {
        switch onboardingManager.currentStep {
        case .microphonePermission:
            return !onboardingManager.hasMicrophonePermission
        case .accessibilityPermission:
            return !onboardingManager.hasAccessibilityPermission
        default:
            return false
        }
    }
}

// MARK: - Progress Indicator

struct ProgressIndicatorView: View {
    let currentStep: OnboardingManager.OnboardingStep
    let steps: [OnboardingManager.OnboardingStep]

    var body: some View {
        HStack(spacing: 8) {
            ForEach(steps, id: \.rawValue) { step in
                Circle()
                    .fill(stepColor(for: step))
                    .frame(width: 8, height: 8)
            }
        }
    }

    private func stepColor(for step: OnboardingManager.OnboardingStep) -> Color {
        if step.rawValue <= currentStep.rawValue {
            // Current and completed steps use accent color
            return DesignConstants.accentColor
        } else {
            // Future steps use gray
            return DesignConstants.tertiaryText
        }
    }
}

// MARK: - Welcome Step

struct WelcomeStepView: View {
    @Binding var isAnimating: Bool

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "bubble.left.fill")
                .font(.system(size: 64))
                .foregroundColor(DesignConstants.accentColor)
                .scaleEffect(isAnimating ? 1.1 : 1.0)
                .animation(
                    Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true),
                    value: isAnimating
                )
                .onAppear { isAnimating = true }

            VStack(spacing: 12) {
                Text("Welcome to TalkFlow")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(DesignConstants.primaryText)

                Text("Turn your voice into text instantly")
                    .font(.title3)
                    .foregroundColor(DesignConstants.secondaryText)
            }

            VStack(alignment: .leading, spacing: 16) {
                FeatureRow(icon: "mic.fill", title: "Press & Hold", description: "Hold your shortcut key to start recording")
                FeatureRow(icon: "text.bubble", title: "Speak Naturally", description: "Say what you want to type")
                FeatureRow(icon: "doc.on.clipboard", title: "Auto-Paste", description: "Text appears wherever you're typing")
            }
            .padding(.top, 16)
        }
        .padding(.horizontal, 40)
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(DesignConstants.accentColor)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(DesignConstants.primaryText)
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(DesignConstants.secondaryText)
            }
        }
    }
}

// MARK: - Microphone Permission Step

struct MicrophonePermissionStepView: View {
    let hasPermission: Bool
    let onRequestPermission: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            PermissionIconView(
                iconName: "mic.fill",
                isGranted: hasPermission
            )

            VStack(spacing: 12) {
                Text("Microphone Access")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(DesignConstants.primaryText)

                Text("TalkFlow needs access to your microphone to capture your voice for transcription.")
                    .font(.body)
                    .foregroundColor(DesignConstants.secondaryText)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 400)
            }

            if hasPermission {
                PermissionGrantedBadge()
            } else {
                Button(action: onRequestPermission) {
                    Label("Grant Microphone Access", systemImage: "mic.fill")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(DesignConstants.accentColor)
                        .cornerRadius(10)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 40)
    }
}

// MARK: - Accessibility Permission Step

struct AccessibilityPermissionStepView: View {
    let hasPermission: Bool
    let onRequestPermission: () -> Void
    let onOpenSettings: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            PermissionIconView(
                iconName: "accessibility",
                isGranted: hasPermission
            )

            VStack(spacing: 12) {
                Text("Accessibility Access")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(DesignConstants.primaryText)

                Text("TalkFlow needs accessibility access to detect keyboard shortcuts globally and paste transcribed text into any application.")
                    .font(.body)
                    .foregroundColor(DesignConstants.secondaryText)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 400)
            }

            if hasPermission {
                PermissionGrantedBadge()
            } else {
                VStack(spacing: 12) {
                    Button(action: onRequestPermission) {
                        Label("Grant Accessibility Access", systemImage: "lock.open.fill")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(DesignConstants.accentColor)
                            .cornerRadius(10)
                    }
                    .buttonStyle(.plain)

                    Text("System Settings will open. Find TalkFlow in the list and toggle it on.")
                        .font(.caption)
                        .foregroundColor(DesignConstants.secondaryText)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 350)
                }
            }
        }
        .padding(.horizontal, 40)
    }
}

// MARK: - Complete Step

struct CompleteStepView: View {
    @State private var isAnimating = false

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(DesignConstants.accentColor)
                .scaleEffect(isAnimating ? 1.0 : 0.5)
                .opacity(isAnimating ? 1.0 : 0.0)
                .animation(.spring(response: 0.5, dampingFraction: 0.6), value: isAnimating)
                .onAppear { isAnimating = true }

            VStack(spacing: 12) {
                Text("You're All Set!")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(DesignConstants.primaryText)

                Text("TalkFlow is ready to use")
                    .font(.title3)
                    .foregroundColor(DesignConstants.secondaryText)
            }

            VStack(alignment: .leading, spacing: 16) {
                TipRow(number: "1", text: "Look for the TalkFlow icon in your menu bar")
                TipRow(number: "2", text: "Press and hold your shortcut key to start recording")
                TipRow(number: "3", text: "Release the key to transcribe and paste")
            }
            .padding(.top, 16)
        }
        .padding(.horizontal, 40)
    }
}

struct TipRow: View {
    let number: String
    let text: String

    var body: some View {
        HStack(spacing: 16) {
            Text(number)
                .font(.headline)
                .foregroundColor(.white)
                .frame(width: 28, height: 28)
                .background(DesignConstants.accentColor)
                .clipShape(Circle())

            Text(text)
                .font(.body)
                .foregroundColor(DesignConstants.primaryText)
        }
    }
}

// MARK: - Shared Components

struct PermissionIconView: View {
    let iconName: String
    let isGranted: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(isGranted ? DesignConstants.accentColor.opacity(0.15) : DesignConstants.tertiaryText.opacity(0.2))
                .frame(width: 100, height: 100)

            Image(systemName: iconName)
                .font(.system(size: 40))
                .foregroundColor(isGranted ? DesignConstants.accentColor : DesignConstants.secondaryText)

            if isGranted {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(DesignConstants.accentColor)
                    .background(Color.white.clipShape(Circle()))
                    .offset(x: 35, y: 35)
            }
        }
    }
}

struct PermissionGrantedBadge: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(DesignConstants.accentColor)
            Text("Permission Granted")
                .font(.headline)
                .foregroundColor(DesignConstants.accentColor)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(DesignConstants.accentColor.opacity(0.15))
        .cornerRadius(20)
    }
}

// MARK: - Preview

#if DEBUG
struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView(onboardingManager: OnboardingManager())
    }
}
#endif
