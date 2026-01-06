import XCTest
@testable import TalkFlow

@MainActor
final class OnboardingManagerTests: XCTestCase {
    var onboardingManager: OnboardingManager!

    override func setUp() async throws {
        try await super.setUp()
        // Clear UserDefaults for clean test state
        UserDefaults.standard.removeObject(forKey: "hasCompletedOnboarding")
        onboardingManager = OnboardingManager()
    }

    override func tearDown() async throws {
        UserDefaults.standard.removeObject(forKey: "hasCompletedOnboarding")
        onboardingManager = nil
        try await super.tearDown()
    }

    // MARK: - Initial State Tests

    func testInitialState_NewUser_ShowsOnboarding() async {
        // New user should see onboarding
        onboardingManager.resetOnboarding()

        XCTAssertTrue(onboardingManager.shouldShowOnboarding, "New user should see onboarding")
        XCTAssertEqual(onboardingManager.currentStep, .welcome, "Should start at welcome step")
    }

    func testInitialState_CompletedUser_WithAllPermissions_HidesOnboarding() {
        // Simulate completed onboarding with permissions
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")

        // Create new manager to check initial state
        let manager = OnboardingManager()

        // Note: This test may show onboarding if permissions are not granted
        // The actual behavior depends on system permission state
        // We're testing the logic, not the actual permission state
        if manager.hasMicrophonePermission && manager.hasAccessibilityPermission {
            XCTAssertFalse(manager.shouldShowOnboarding, "Completed user with all permissions should not see onboarding")
        }
    }

    // MARK: - Step Navigation Tests

    func testNextStep_FromWelcome_GoesToMicrophone() {
        onboardingManager.currentStep = .welcome
        onboardingManager.nextStep()

        XCTAssertEqual(onboardingManager.currentStep, .microphonePermission)
    }

    func testNextStep_FromMicrophone_GoesToAccessibility() {
        onboardingManager.currentStep = .microphonePermission
        onboardingManager.nextStep()

        XCTAssertEqual(onboardingManager.currentStep, .accessibilityPermission)
    }

    func testNextStep_FromAccessibility_GoesToComplete() {
        onboardingManager.currentStep = .accessibilityPermission
        onboardingManager.nextStep()

        XCTAssertEqual(onboardingManager.currentStep, .complete)
    }

    func testGoToStep_NavigatesToCorrectStep() {
        onboardingManager.goToStep(.accessibilityPermission)

        XCTAssertEqual(onboardingManager.currentStep, .accessibilityPermission)
    }

    func testSkipCurrentStep_AdvancesToNextStep() {
        onboardingManager.currentStep = .microphonePermission
        onboardingManager.skipCurrentStep()

        XCTAssertEqual(onboardingManager.currentStep, .accessibilityPermission)
    }

    // MARK: - Completion Tests

    func testCompleteOnboarding_SetsCompletionFlag() {
        onboardingManager.completeOnboarding()

        XCTAssertTrue(UserDefaults.standard.bool(forKey: "hasCompletedOnboarding"))
        XCTAssertFalse(onboardingManager.shouldShowOnboarding)
    }

    func testResetOnboarding_ClearsCompletionFlag() {
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")

        onboardingManager.resetOnboarding()

        XCTAssertFalse(UserDefaults.standard.bool(forKey: "hasCompletedOnboarding"))
        XCTAssertTrue(onboardingManager.shouldShowOnboarding)
        XCTAssertEqual(onboardingManager.currentStep, .welcome)
    }

    // MARK: - Step Properties Tests

    func testStepTitles_AreNotEmpty() {
        for step in OnboardingManager.OnboardingStep.allCases {
            XCTAssertFalse(step.title.isEmpty, "Step \(step) should have a title")
        }
    }

    func testStepDescriptions_AreNotEmpty() {
        for step in OnboardingManager.OnboardingStep.allCases {
            XCTAssertFalse(step.description.isEmpty, "Step \(step) should have a description")
        }
    }

    func testStepIconNames_AreNotEmpty() {
        for step in OnboardingManager.OnboardingStep.allCases {
            XCTAssertFalse(step.iconName.isEmpty, "Step \(step) should have an icon name")
        }
    }

    // MARK: - Permission State Tests

    func testDetermineOnboardingState_MissingMicPermission_ShowsOnboarding() {
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")

        let manager = OnboardingManager()

        // If microphone permission is missing, onboarding should show
        if !manager.hasMicrophonePermission {
            XCTAssertTrue(manager.shouldShowOnboarding, "Should show onboarding when microphone permission is missing")
            XCTAssertEqual(manager.currentStep, .microphonePermission, "Should start at microphone step")
        }
    }

    func testDetermineOnboardingState_MissingAccessibilityPermission_ShowsOnboarding() {
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")

        let manager = OnboardingManager()

        // If accessibility permission is missing (but mic is granted), should show accessibility step
        if manager.hasMicrophonePermission && !manager.hasAccessibilityPermission {
            XCTAssertTrue(manager.shouldShowOnboarding, "Should show onboarding when accessibility permission is missing")
            XCTAssertEqual(manager.currentStep, .accessibilityPermission, "Should start at accessibility step")
        }
    }
}
