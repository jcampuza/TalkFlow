import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var statusIndicatorWindow: StatusIndicatorWindow?
    private var menuBarController: MenuBarController?
    private var accessibilityCheckTimer: Timer?
    private var isAccessibilityEnabled = false

    let dependencyContainer = DependencyContainer()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Setup main menu
        setupMainMenu()

        // Initialize logger
        Logger.shared.info("TalkFlow starting up", component: "App")

        // Setup menu bar
        setupMenuBar()

        // Setup status indicator
        setupStatusIndicator()

        // Request permissions and start monitoring
        requestPermissionsIfNeeded()

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
            self?.checkAccessibilityPermission()
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
            onShowHistory: { [weak self] in
                self?.showHistoryWindow()
            },
            onShowSettings: { [weak self] in
                self?.showSettingsWindow()
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

    private func showHistoryWindow() {
        NSApp.activate(ignoringOtherApps: true)

        if let window = NSApp.windows.first(where: { $0.identifier?.rawValue == "history" }) {
            window.makeKeyAndOrderFront(nil)
        } else {
            // Open window via scene
            if let url = URL(string: "talkflow://history") {
                NSWorkspace.shared.open(url)
            }
        }
    }

    private func showSettingsWindow() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
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
        fileMenu.addItem(withTitle: "View History", action: #selector(openHistory), keyEquivalent: "h")
        fileMenu.items.last?.keyEquivalentModifierMask = [.command, .shift]
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
        showSettingsWindow()
    }

    @objc private func openHistory() {
        showHistoryWindow()
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
                let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
                _ = AXIsProcessTrustedWithOptions(options as CFDictionary)
            }
        }
    }
}
