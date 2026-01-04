import SwiftUI
import AppKit
import Combine

final class StatusIndicatorWindow: NSObject {
    private var window: NSWindow?
    private var stateManager: IndicatorStateManager
    private var configurationManager: ConfigurationManager

    private var cancellables = Set<AnyCancellable>()

    init(stateManager: IndicatorStateManager, configurationManager: ConfigurationManager) {
        self.stateManager = stateManager
        self.configurationManager = configurationManager

        super.init()

        setupWindow()
        observeState()
    }

    private func setupWindow() {
        let contentView = StatusIndicatorView(stateManager: stateManager)

        let hostingController = NSHostingController(rootView: contentView)

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

        // Set initial position
        positionWindow(window)

        self.window = window
    }

    private func observeState() {
        stateManager.$state
            .sink { [weak self] state in
                self?.updateVisibility(for: state)
            }
            .store(in: &cancellables)
    }

    private func updateVisibility(for state: IndicatorState) {
        guard let window = window else { return }

        let showWhenIdle = configurationManager.configuration.indicatorVisibleWhenIdle

        // Always show for persistent states (like permissionRequired)
        if state.isPersistent {
            positionWindowOnCursorScreen(window)
            window.orderFrontRegardless()
        } else if state == .idle && !showWhenIdle {
            window.orderOut(nil)
        } else {
            // Position on screen with cursor
            positionWindowOnCursorScreen(window)
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

        // Check if we have a saved position
        if let savedPosition = configurationManager.configuration.indicatorPosition {
            // Adjust position to be relative to current screen
            let x = screen.visibleFrame.maxX - (NSScreen.main?.visibleFrame.maxX ?? 0 - savedPosition.x)
            let y = savedPosition.y

            // Ensure window stays on screen
            let windowSize = window.frame.size
            let adjustedX = min(max(x, screen.visibleFrame.minX), screen.visibleFrame.maxX - windowSize.width)
            let adjustedY = min(max(y, screen.visibleFrame.minY), screen.visibleFrame.maxY - windowSize.height)

            window.setFrameOrigin(NSPoint(x: adjustedX, y: adjustedY))
        } else {
            // Default position on target screen
            let padding: CGFloat = 40
            let windowSize = window.frame.size

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
