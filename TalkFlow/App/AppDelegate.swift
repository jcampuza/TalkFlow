@preconcurrency import AppKit
import SwiftUI

// Helper function to safely request accessibility prompt
// Uses the string value directly to avoid Swift 6 concurrency issues with C globals
private nonisolated func requestAccessibilityPromptHelper() {
    // kAXTrustedCheckOptionPrompt's string value is "AXTrustedCheckOptionPrompt"
    let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
    _ = AXIsProcessTrustedWithOptions(options)
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var statusItem: NSStatusItem!
    private var statusIndicatorWindow: StatusIndicatorWindow?
    private var menuBarController: MenuBarController?
    private var mainWindow: NSWindow?
    private var accessibilityCheckTimer: Timer?
    private var isAccessibilityEnabled = false

    let dependencyContainer = DependencyContainer()

    /// Check if another instance of TalkFlow is already running
    /// Multiple instances with CGEvent taps can cause system-wide keyboard freezes
    private func terminateIfAlreadyRunning() -> Bool {
        let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier ?? "")
        let otherInstances = runningApps.filter { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }

        if !otherInstances.isEmpty {
            Logger.shared.warning("Another instance of TalkFlow is already running (PID: \(otherInstances.first?.processIdentifier ?? 0)). Terminating this instance.", component: "App")

            // Show alert to user
            let alert = NSAlert()
            alert.messageText = "TalkFlow Already Running"
            alert.informativeText = "Another instance of TalkFlow is already running. Only one instance can run at a time to prevent keyboard issues."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
            NSApp.terminate(nil)
            return true
        }
        return false
    }

    /// Returns true if running inside XCTest (Xcode sets this environment variable)
    /// This is the official Apple-recommended way to detect test execution
    private var isRunningInTestEnvironment: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Skip UI initialization when running unit tests
        // Tests still get access to app symbols via TEST_HOST, but we don't want UI
        if isRunningInTestEnvironment {
            Logger.shared.info("Running in test environment - skipping UI setup", component: "App")
            return
        }

        // CRITICAL: Check for existing instances first to prevent keyboard freezes
        // Multiple CGEvent taps from multiple app instances can freeze keyboard input
        if terminateIfAlreadyRunning() {
            return
        }

        // Start as menu bar only app (no dock icon until window is opened)
        NSApp.setActivationPolicy(.accessory)

        // Setup main menu
        setupMainMenu()

        // Initialize logger
        Logger.shared.info("TalkFlow starting up", component: "App")

        // Migrate keychain entry to use proper access control (prevents repeated permission prompts)
        dependencyContainer.keychainService.migrateIfNeeded()

        // Setup menu bar
        setupMenuBar()

        // Setup status indicator
        setupStatusIndicator()

        // Always show main window on launch
        Logger.shared.info("Showing main window", component: "App")
        // Delay slightly to ensure window is ready
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(100))
            self?.showMainWindow()
        }

        // Request permissions if not in onboarding
        if !dependencyContainer.onboardingManager.shouldShowOnboarding {
            requestPermissionsIfNeeded()
        }

        // Try to start shortcut monitoring
        startShortcutMonitoringIfPossible()

        // Start periodic accessibility check
        startAccessibilityCheck()

        Logger.shared.info("TalkFlow started successfully", component: "App")
    }

    func applicationWillTerminate(_ notification: Notification) {
        Logger.shared.info("TalkFlow shutting down", component: "App")
        accessibilityCheckTimer?.invalidate()
        accessibilityCheckTimer = nil
        dependencyContainer.shortcutManager.stopMonitoring()
    }

    private func startShortcutMonitoringIfPossible() {
        let accessibilityEnabled = AXIsProcessTrusted()
        isAccessibilityEnabled = accessibilityEnabled

        if accessibilityEnabled {
            dependencyContainer.shortcutManager.startMonitoring()
            dependencyContainer.indicatorStateManager.clearPermissionRequired()
            Logger.shared.info("Accessibility enabled, shortcut monitoring started", component: "App")
        } else {
            dependencyContainer.indicatorStateManager.showPermissionRequired()
            Logger.shared.warning("Accessibility not enabled, showing permission indicator", component: "App")
        }
    }

    private func startAccessibilityCheck() {
        // Check every 2 seconds if accessibility permission has been granted
        accessibilityCheckTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkAccessibilityPermission()
            }
        }
    }

    private func checkAccessibilityPermission() {
        let currentlyEnabled = AXIsProcessTrusted()

        // If permission was just granted
        if currentlyEnabled && !isAccessibilityEnabled {
            isAccessibilityEnabled = true
            Logger.shared.info("Accessibility permission granted", component: "App")

            // Start shortcut monitoring
            dependencyContainer.shortcutManager.startMonitoring()
            dependencyContainer.indicatorStateManager.clearPermissionRequired()

            // Stop checking (we got permission)
            accessibilityCheckTimer?.invalidate()
            accessibilityCheckTimer = nil
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Keep app running even when all windows are closed (menu bar app)
        return false
    }

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "bubble.left.fill", accessibilityDescription: "TalkFlow")
        }

        menuBarController = MenuBarController(
            statusItem: statusItem,
            historyStorage: dependencyContainer.historyStorage,
            onOpenTalkFlow: { [weak self] in
                self?.showMainWindow()
            },
            onQuit: {
                NSApp.terminate(nil)
            }
        )
    }

    private func setupStatusIndicator() {
        statusIndicatorWindow = StatusIndicatorWindow(
            stateManager: dependencyContainer.indicatorStateManager,
            configurationManager: dependencyContainer.configurationManager
        )
    }

    func showMainWindow() {
        // Show in Dock when window is open (allows Cmd+Tab)
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        // Reuse existing window if available
        if let window = mainWindow {
            window.makeKeyAndOrderFront(nil)
            return
        }

        // Create window programmatically (menu bar apps don't use SwiftUI Window scenes)
        let contentView = MainWindowView(onboardingManager: dependencyContainer.onboardingManager)
            .environment(\.configurationManager, dependencyContainer.configurationManager)
            .environment(\.historyStorage, dependencyContainer.historyStorage)
            .environment(\.dictionaryManager, dependencyContainer.dictionaryManager)

        let hostingController = NSHostingController(rootView: contentView)

        let window = NSWindow(contentViewController: hostingController)
        window.identifier = NSUserInterfaceItemIdentifier("main")
        window.title = "TalkFlow"
        window.setContentSize(NSSize(width: 700, height: 500))
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.isReleasedWhenClosed = false  // Keep window in memory for reopening
        window.delegate = self
        window.appearance = NSAppearance(named: .aqua)  // Force light mode titlebar
        window.center()
        window.makeKeyAndOrderFront(nil)

        mainWindow = window
    }

    // MARK: - NSWindowDelegate

    func windowWillClose(_ notification: Notification) {
        guard let closingWindow = notification.object as? NSWindow else { return }

        // When main window closes, hide from Dock (menu bar only mode)
        if closingWindow.identifier?.rawValue == "main" {
            // Check if any other windows are visible (besides status indicator)
            let hasOtherVisibleWindows = NSApp.windows.contains { window in
                window != closingWindow &&
                window.isVisible &&
                window.identifier?.rawValue != "status-indicator" &&
                !(window is NSPanel)  // Ignore panels
            }

            if !hasOtherVisibleWindows {
                // No windows open - hide from Dock
                NSApp.setActivationPolicy(.accessory)
            }
        }
    }

    private func setupMainMenu() {
        let mainMenu = NSMenu()

        // App menu (TalkFlow)
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "About TalkFlow", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Settings...", action: #selector(openSettings), keyEquivalent: ",")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Hide TalkFlow", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        let hideOthersItem = appMenu.addItem(withTitle: "Hide Others", action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        hideOthersItem.keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(withTitle: "Show All", action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Quit TalkFlow", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        // File menu
        let fileMenuItem = NSMenuItem()
        let fileMenu = NSMenu(title: "File")
        fileMenu.addItem(withTitle: "New Window", action: #selector(openMainWindow), keyEquivalent: "n")
        fileMenu.addItem(withTitle: "Close Window", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        fileMenuItem.submenu = fileMenu
        mainMenu.addItem(fileMenuItem)

        // Edit menu (standard)
        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)

        // Window menu
        let windowMenuItem = NSMenuItem()
        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowMenu.addItem(withTitle: "Zoom", action: #selector(NSWindow.performZoom(_:)), keyEquivalent: "")
        windowMenu.addItem(NSMenuItem.separator())
        windowMenu.addItem(withTitle: "Bring All to Front", action: #selector(NSApplication.arrangeInFront(_:)), keyEquivalent: "")
        windowMenuItem.submenu = windowMenu
        mainMenu.addItem(windowMenuItem)

        // Help menu
        let helpMenuItem = NSMenuItem()
        let helpMenu = NSMenu(title: "Help")
        helpMenu.addItem(withTitle: "TalkFlow Help", action: #selector(showHelp), keyEquivalent: "?")
        helpMenuItem.submenu = helpMenu
        mainMenu.addItem(helpMenuItem)

        NSApp.mainMenu = mainMenu
        NSApp.windowsMenu = windowMenu
        NSApp.helpMenu = helpMenu
    }

    @objc private func openSettings() {
        showMainWindow()
    }

    @objc private func openMainWindow() {
        showMainWindow()
    }

    @objc private func showHelp() {
        if let url = URL(string: "https://github.com/josephcampuzano/TalkFlow") {
            NSWorkspace.shared.open(url)
        }
    }

    private func requestPermissionsIfNeeded() {
        // Request microphone access
        dependencyContainer.audioCaptureService.requestMicrophoneAccess { granted in
            if !granted {
                Logger.shared.warning("Microphone access denied", component: "App")
            }
        }

        // Check accessibility permission without prompting first
        let accessibilityEnabled = AXIsProcessTrusted()

        if !accessibilityEnabled {
            Logger.shared.warning("Accessibility access not enabled", component: "App")

            // Only prompt on first launch (check UserDefaults)
            let hasPromptedKey = "hasPromptedForAccessibility"
            if !UserDefaults.standard.bool(forKey: hasPromptedKey) {
                UserDefaults.standard.set(true, forKey: hasPromptedKey)
                // Prompt user to grant accessibility access
                requestAccessibilityPromptHelper()
            }
        }
    }
}
