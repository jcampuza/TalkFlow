import Foundation
import AVFoundation
import Observation
@preconcurrency import AppKit

// Helper function to safely request accessibility prompt
// Uses the string value directly to avoid Swift 6 concurrency issues with C globals
private nonisolated func requestAccessibilityPrompt() {
    // kAXTrustedCheckOptionPrompt's string value is "AXTrustedCheckOptionPrompt"
    let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
    _ = AXIsProcessTrustedWithOptions(options)
}

/// Manages onboarding state and permission status for the app
@Observable
final class OnboardingManager: @unchecked Sendable {

    enum OnboardingStep: Int, CaseIterable, Sendable {
        case welcome = 0
        case microphonePermission = 1
        case accessibilityPermission = 2
        case complete = 3

        var title: String {
            switch self {
            case .welcome:
                return "Welcome to TalkFlow"
            case .microphonePermission:
                return "Microphone Access"
            case .accessibilityPermission:
                return "Accessibility Access"
            case .complete:
                return "You're All Set!"
            }
        }

        var description: String {
            switch self {
            case .welcome:
                return "TalkFlow turns your voice into text instantly. Press and hold a key to record, release to transcribe."
            case .microphonePermission:
                return "TalkFlow needs access to your microphone to capture your voice for transcription."
            case .accessibilityPermission:
                return "TalkFlow needs accessibility access to detect keyboard shortcuts and paste transcribed text into any app."
            case .complete:
                return "TalkFlow is ready to use. Click the menu bar icon to get started, or press and hold your shortcut key to begin dictating."
            }
        }

        var iconName: String {
            switch self {
            case .welcome:
                return "bubble.left.fill"
            case .microphonePermission:
                return "mic.fill"
            case .accessibilityPermission:
                return "accessibility"
            case .complete:
                return "checkmark.circle.fill"
            }
        }
    }

    // MARK: - Observable Properties

    @MainActor var currentStep: OnboardingStep = .welcome
    @MainActor var hasMicrophonePermission: Bool = false
    @MainActor var hasAccessibilityPermission: Bool = false
    @MainActor var shouldShowOnboarding: Bool = false

    // MARK: - Private Properties

    private static let hasCompletedOnboardingKey = "hasCompletedOnboarding"
    private var permissionCheckTimer: Timer?

    // MARK: - Initialization

    @MainActor
    init() {
        checkInitialPermissions()
        determineOnboardingState()
    }

    deinit {
        permissionCheckTimer?.invalidate()
    }

    // MARK: - Public Methods

    /// Check if onboarding should be shown based on completion status and permissions
    @MainActor
    func determineOnboardingState() {
        let hasCompletedOnboarding = UserDefaults.standard.bool(forKey: Self.hasCompletedOnboardingKey)

        // Show onboarding if:
        // 1. User has never completed onboarding, OR
        // 2. User is missing required permissions
        if !hasCompletedOnboarding || !hasAllRequiredPermissions {
            shouldShowOnboarding = true

            // Determine which step to start on
            if hasCompletedOnboarding && !hasAllRequiredPermissions {
                // User completed onboarding before but is missing permissions
                if !hasMicrophonePermission {
                    currentStep = .microphonePermission
                } else if !hasAccessibilityPermission {
                    currentStep = .accessibilityPermission
                }
            } else {
                currentStep = .welcome
            }
        } else {
            shouldShowOnboarding = false
        }
    }

    /// Check current permission status
    @MainActor
    func checkInitialPermissions() {
        checkMicrophonePermission()
        checkAccessibilityPermission()
    }

    /// Request microphone permission from the system
    @MainActor
    func requestMicrophonePermission() {
        AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
            Task { @MainActor in
                self?.hasMicrophonePermission = granted
                if granted {
                    Logger.shared.info("Microphone permission granted via onboarding", component: "Onboarding")
                } else {
                    Logger.shared.warning("Microphone permission denied via onboarding", component: "Onboarding")
                }
            }
        }
    }

    /// Request accessibility permission and open System Settings
    @MainActor
    func requestAccessibilityPermission() {
        // Try to trigger the system prompt (only works once per app install)
        requestAccessibilityPrompt()

        // Always open System Settings as well, since the prompt only shows once
        openAccessibilitySettings()

        Logger.shared.info("Accessibility permission requested via onboarding", component: "Onboarding")
    }

    /// Open System Settings directly to Accessibility > Privacy
    @MainActor
    func openAccessibilitySettings() {
        // Try to open the accessibility pane directly
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }

        // Start polling for permission changes
        startAccessibilityPermissionPolling()
    }

    /// Move to the next onboarding step
    @MainActor
    func nextStep() {
        guard let nextIndex = OnboardingStep(rawValue: currentStep.rawValue + 1) else {
            completeOnboarding()
            return
        }
        currentStep = nextIndex
    }

    /// Move to a specific step
    @MainActor
    func goToStep(_ step: OnboardingStep) {
        currentStep = step
    }

    /// Skip the current permission step (if allowed)
    @MainActor
    func skipCurrentStep() {
        nextStep()
    }

    /// Mark onboarding as complete
    @MainActor
    func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: Self.hasCompletedOnboardingKey)
        permissionCheckTimer?.invalidate()
        permissionCheckTimer = nil
        shouldShowOnboarding = false
        Logger.shared.info("Onboarding completed", component: "Onboarding")
    }

    /// Reset onboarding state (for testing)
    @MainActor
    func resetOnboarding() {
        UserDefaults.standard.set(false, forKey: Self.hasCompletedOnboardingKey)
        currentStep = .welcome
        checkInitialPermissions()
        determineOnboardingState()
    }

    // MARK: - Private Methods

    @MainActor
    private var hasAllRequiredPermissions: Bool {
        return hasMicrophonePermission && hasAccessibilityPermission
    }

    @MainActor
    private func checkMicrophonePermission() {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            hasMicrophonePermission = true
        case .denied, .restricted:
            hasMicrophonePermission = false
        case .notDetermined:
            hasMicrophonePermission = false
        @unknown default:
            hasMicrophonePermission = false
        }
    }

    @MainActor
    private func checkAccessibilityPermission() {
        hasAccessibilityPermission = AXIsProcessTrusted()
    }

    @MainActor
    private func startAccessibilityPermissionPolling() {
        permissionCheckTimer?.invalidate()
        permissionCheckTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkAccessibilityPermission()
            }
        }
    }
}
