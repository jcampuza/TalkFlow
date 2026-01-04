import AppKit

final class ClipboardManager {
    private var savedItems: [NSPasteboardItem]?
    private var savedChangeCount: Int?

    func save() {
        let pasteboard = NSPasteboard.general
        savedChangeCount = pasteboard.changeCount

        savedItems = pasteboard.pasteboardItems?.compactMap { item -> NSPasteboardItem? in
            let copy = NSPasteboardItem()

            for type in item.types {
                if let data = item.data(forType: type) {
                    copy.setData(data, forType: type)
                }
            }

            return copy
        }

        Logger.shared.debug("Clipboard saved, \(savedItems?.count ?? 0) items", component: "ClipboardManager")
    }

    func restore() {
        guard let items = savedItems else {
            Logger.shared.debug("No clipboard to restore", component: "ClipboardManager")
            return
        }

        let pasteboard = NSPasteboard.general

        // Only restore if the clipboard was changed by us
        // (This prevents losing content if user copied something else in the meantime)
        if pasteboard.changeCount != (savedChangeCount ?? 0) + 1 {
            Logger.shared.debug("Clipboard changed externally, not restoring", component: "ClipboardManager")
            savedItems = nil
            savedChangeCount = nil
            return
        }

        pasteboard.clearContents()

        for item in items {
            let newItem = NSPasteboardItem()
            for type in item.types {
                if let data = item.data(forType: type) {
                    newItem.setData(data, forType: type)
                }
            }
            pasteboard.writeObjects([newItem])
        }

        savedItems = nil
        savedChangeCount = nil

        Logger.shared.debug("Clipboard restored", component: "ClipboardManager")
    }

    func setString(_ string: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(string, forType: .string)
    }

    func getString() -> String? {
        return NSPasteboard.general.string(forType: .string)
    }
}
