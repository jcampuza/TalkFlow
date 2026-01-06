import SwiftUI
import AppKit

/// Window controller for the Dictionary window
final class DictionaryWindowController {
    private var window: NSWindow?
    private let manager: DictionaryManager

    init(manager: DictionaryManager) {
        self.manager = manager
    }

    func showWindow() {
        if let existingWindow = window {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let contentView = DictionaryView(manager: manager)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 450, height: 500),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )

        window.title = "Dictionary"
        window.center()
        window.contentView = NSHostingView(rootView: contentView)
        window.minSize = NSSize(width: 400, height: 300)
        window.isReleasedWhenClosed = false

        // Set window identifier
        window.identifier = NSUserInterfaceItemIdentifier("dictionary")

        self.window = window

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        Logger.shared.debug("Dictionary window opened", component: "DictionaryWindow")
    }

    func closeWindow() {
        window?.close()
        window = nil
    }
}
