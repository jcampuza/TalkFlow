import AppKit
import Combine

final class MenuBarController: NSObject {
    private let statusItem: NSStatusItem
    private let historyStorage: HistoryStorage
    private let onShowHistory: () -> Void
    private let onShowSettings: () -> Void
    private let onQuit: () -> Void

    private var cancellables = Set<AnyCancellable>()

    init(
        statusItem: NSStatusItem,
        historyStorage: HistoryStorage,
        onShowHistory: @escaping () -> Void,
        onShowSettings: @escaping () -> Void,
        onQuit: @escaping () -> Void
    ) {
        self.statusItem = statusItem
        self.historyStorage = historyStorage
        self.onShowHistory = onShowHistory
        self.onShowSettings = onShowSettings
        self.onQuit = onQuit

        super.init()

        setupMenu()
        observeHistory()
    }

    private func setupMenu() {
        statusItem.menu = createMenu()
    }

    private func observeHistory() {
        historyStorage.$recentRecords
            .sink { [weak self] _ in
                self?.updateMenu()
            }
            .store(in: &cancellables)
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

        // View All History
        let historyItem = NSMenuItem(
            title: "View All History...",
            action: #selector(showHistory),
            keyEquivalent: "h"
        )
        historyItem.keyEquivalentModifierMask = [.command, .shift]
        historyItem.target = self
        menu.addItem(historyItem)

        menu.addItem(NSMenuItem.separator())

        // Settings
        let settingsItem = NSMenuItem(
            title: "Settings...",
            action: #selector(showSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

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

    @objc private func showHistory() {
        onShowHistory()
    }

    @objc private func showSettings() {
        onShowSettings()
    }

    @objc private func quit() {
        onQuit()
    }

    private func showCopiedNotification() {
        // Update menu bar icon briefly to indicate copy
        if let button = statusItem.button {
            let originalImage = button.image
            button.image = NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: "Copied")

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                button.image = originalImage
            }
        }
    }
}
