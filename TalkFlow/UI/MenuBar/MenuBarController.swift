import AppKit

@MainActor
final class MenuBarController: NSObject {
    private let statusItem: NSStatusItem
    private let historyStorage: HistoryStorage
    private let onOpenTalkFlow: @MainActor () -> Void
    private let onQuit: @MainActor () -> Void

    init(
        statusItem: NSStatusItem,
        historyStorage: HistoryStorage,
        onOpenTalkFlow: @escaping @MainActor () -> Void,
        onQuit: @escaping @MainActor () -> Void
    ) {
        self.statusItem = statusItem
        self.historyStorage = historyStorage
        self.onOpenTalkFlow = onOpenTalkFlow
        self.onQuit = onQuit

        super.init()

        setupMenu()
        observeHistory()
    }

    private func setupMenu() {
        statusItem.menu = createMenu()
    }

    private func observeHistory() {
        withObservationTracking {
            _ = historyStorage.recentRecords
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.updateMenu()
                self?.observeHistory()  // Re-register for future changes
            }
        }
    }

    private func updateMenu() {
        statusItem.menu = createMenu()
    }

    private func createMenu() -> NSMenu {
        let menu = NSMenu()

        // Recent transcriptions header
        if !historyStorage.recentRecords.isEmpty {
            let headerItem = NSMenuItem(title: "Recent Transcriptions", action: nil, keyEquivalent: "")
            headerItem.isEnabled = false
            menu.addItem(headerItem)

            // Recent items (up to 5)
            for record in historyStorage.recentRecords.prefix(5) {
                let item = NSMenuItem(
                    title: record.preview,
                    action: #selector(copyRecentItem(_:)),
                    keyEquivalent: ""
                )
                item.target = self
                item.representedObject = record
                item.toolTip = record.text

                // Add relative timestamp as subtitle
                let subtitle = record.relativeTimestamp
                let attributedTitle = NSMutableAttributedString(string: record.preview)
                attributedTitle.append(NSAttributedString(
                    string: "  \(subtitle)",
                    attributes: [
                        .foregroundColor: NSColor.secondaryLabelColor,
                        .font: NSFont.systemFont(ofSize: 11)
                    ]
                ))
                item.attributedTitle = attributedTitle

                menu.addItem(item)
            }

            menu.addItem(NSMenuItem.separator())
        }

        // Open TalkFlow (main window with all features)
        let openItem = NSMenuItem(
            title: "Open TalkFlow...",
            action: #selector(openTalkFlow),
            keyEquivalent: "o"
        )
        openItem.target = self
        menu.addItem(openItem)

        menu.addItem(NSMenuItem.separator())

        // Quit
        let quitItem = NSMenuItem(
            title: "Quit TalkFlow",
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        return menu
    }

    @objc private func copyRecentItem(_ sender: NSMenuItem) {
        guard let record = sender.representedObject as? TranscriptionRecord else { return }

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(record.text, forType: .string)

        // Show brief notification that text was copied
        showCopiedNotification()

        Logger.shared.debug("Copied transcription to clipboard", component: "MenuBar")
    }

    @objc private func openTalkFlow() {
        onOpenTalkFlow()
    }

    @objc private func quit() {
        onQuit()
    }

    private func showCopiedNotification() {
        // Update menu bar icon briefly to indicate copy
        if let button = statusItem.button {
            let originalImage = button.image
            button.image = NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: "Copied")

            Task { @MainActor in
                try? await Task.sleep(for: .seconds(1))
                button.image = originalImage
            }
        }
    }
}
