import SwiftUI
import AppKit

@MainActor
final class StatusIndicatorWindow: NSObject {
    private var window: NSWindow?
    private var stateManager: IndicatorStateManager
    private var configurationManager: ConfigurationManager
    nonisolated(unsafe) private var windowMoveObserver: NSObjectProtocol?

    init(stateManager: IndicatorStateManager, configurationManager: ConfigurationManager) {
        self.stateManager = stateManager
        self.configurationManager = configurationManager

        super.init()

        setupWindow()
        setupObservers()
        setupWindowMoveObserver()
    }

    deinit {
        if let observer = windowMoveObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    private func setupWindowMoveObserver() {
        guard let window = window else { return }
        windowMoveObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didMoveNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.savePosition()
            }
        }
    }

    private func setupWindow() {
        let contentView = StatusIndicatorView(stateManager: stateManager)

        let hostingController = NSHostingController(rootView: contentView)
        hostingController.view.wantsLayer = true
        hostingController.view.layer?.backgroundColor = .clear

        let window = NSWindow(contentViewController: hostingController)
        window.styleMask = [.borderless]
        window.level = .floating
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.isReleasedWhenClosed = false

        // Make window draggable
        window.isMovableByWindowBackground = true

        self.window = window

        // Defer initial positioning until next run loop to ensure SwiftUI has laid out the view
        // and window has its proper size
        Task { @MainActor [weak self] in
            guard let self = self, let window = self.window else { return }
            // Use positionWindowOnCursorScreen which has proper bounds checking
            self.positionWindowOnCursorScreen(window)
            // Set initial visibility based on current configuration
            self.updateVisibility(for: self.stateManager.state)
        }
    }

    private func setupObservers() {
        // Use withObservationTracking for @Observable objects
        withObservationTracking {
            // Access the properties we want to track
            _ = stateManager.state
            _ = configurationManager.configuration.indicatorVisibleWhenIdle
        } onChange: { [weak self] in
            // This closure is called when any tracked property changes
            // Schedule on MainActor and re-register for future changes
            Task { @MainActor in
                guard let self else { return }
                self.updateVisibility(for: self.stateManager.state)
                self.setupObservers()  // Re-register for future changes
            }
        }
    }

    @MainActor
    private func updateVisibility(for state: IndicatorState) {
        guard let window = window else { return }

        let showWhenIdle = configurationManager.configuration.indicatorVisibleWhenIdle
        let wasVisible = window.isVisible

        // Always show for persistent states (like permissionRequired)
        if state.isPersistent {
            if !wasVisible {
                positionWindowOnCursorScreen(window)
            }
            window.orderFrontRegardless()
        } else if state == .idle && !showWhenIdle {
            window.orderOut(nil)
        } else {
            // Only reposition if window wasn't already visible
            if !wasVisible {
                positionWindowOnCursorScreen(window)
            }
            window.orderFrontRegardless()
        }
    }

    private func positionWindow(_ window: NSWindow) {
        if let savedPosition = configurationManager.configuration.indicatorPosition {
            window.setFrameOrigin(NSPoint(x: savedPosition.x, y: savedPosition.y))
        } else {
            positionWindowDefault(window)
        }
    }

    private func positionWindowDefault(_ window: NSWindow) {
        guard let screen = NSScreen.main else { return }

        let padding: CGFloat = 40
        let windowSize = window.frame.size

        let x = screen.visibleFrame.maxX - windowSize.width - padding
        let y = screen.visibleFrame.minY + padding

        window.setFrameOrigin(NSPoint(x: x, y: y))
    }

    private func positionWindowOnCursorScreen(_ window: NSWindow) {
        let mouseLocation = NSEvent.mouseLocation

        // Find screen containing cursor
        let targetScreen = NSScreen.screens.first { screen in
            NSPointInRect(mouseLocation, screen.frame)
        } ?? NSScreen.main

        guard let screen = targetScreen else { return }

        let windowSize = window.frame.size

        // Check if we have a saved position
        if let savedPosition = configurationManager.configuration.indicatorPosition {
            // Use saved position but ensure it stays within screen bounds
            let adjustedX = min(max(savedPosition.x, screen.visibleFrame.minX), screen.visibleFrame.maxX - windowSize.width)
            let adjustedY = min(max(savedPosition.y, screen.visibleFrame.minY), screen.visibleFrame.maxY - windowSize.height)

            window.setFrameOrigin(NSPoint(x: adjustedX, y: adjustedY))
        } else {
            // Default position: bottom-right of target screen with padding
            let padding: CGFloat = 40

            let x = screen.visibleFrame.maxX - windowSize.width - padding
            let y = screen.visibleFrame.minY + padding

            window.setFrameOrigin(NSPoint(x: x, y: y))
        }
    }

    func savePosition() {
        guard let window = window else { return }

        let position = window.frame.origin
        var config = configurationManager.configuration
        config.indicatorPosition = CGPoint(x: position.x, y: position.y)
        configurationManager.configuration = config

        Logger.shared.debug("Saved indicator position: \(position)", component: "StatusIndicator")
    }

    func resetPosition() {
        guard let window = window else { return }

        var config = configurationManager.configuration
        config.indicatorPosition = nil
        configurationManager.configuration = config

        positionWindowDefault(window)

        Logger.shared.debug("Reset indicator position to default", component: "StatusIndicator")
    }
}
