import AppKit
import ApplicationServices

final class TextOutputManager {
    private let clipboardManager: ClipboardManager

    init(clipboardManager: ClipboardManager) {
        self.clipboardManager = clipboardManager
    }

    func insert(_ text: String) {
        Logger.shared.info("Inserting text (\(text.count) characters)", component: "TextOutput")

        // Save current clipboard
        clipboardManager.save()

        // Try accessibility-based insertion first
        if insertViaAccessibility(text) {
            Logger.shared.debug("Text inserted via accessibility API", component: "TextOutput")
            clipboardManager.restore()
            return
        }

        // Fallback to clipboard + paste
        Logger.shared.debug("Falling back to clipboard paste", component: "TextOutput")
        insertViaClipboard(text)

        // Restore clipboard after a short delay to let paste complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.clipboardManager.restore()
        }
    }

    private func insertViaAccessibility(_ text: String) -> Bool {
        guard let focusedElement = getFocusedElement() else {
            Logger.shared.debug("No focused element found", component: "TextOutput")
            return false
        }

        // Check if the element is editable
        var isEditable: AnyObject?
        AXUIElementCopyAttributeValue(focusedElement, kAXRoleAttribute as CFString, &isEditable)

        // Try to set the value
        let result = AXUIElementSetAttributeValue(focusedElement, kAXValueAttribute as CFString, text as CFTypeRef)

        if result == .success {
            return true
        }

        // Try inserting at selection if setting value failed
        if insertAtSelection(focusedElement, text: text) {
            return true
        }

        Logger.shared.debug("Accessibility insertion failed with code: \(result.rawValue)", component: "TextOutput")
        return false
    }

    private func getFocusedElement() -> AXUIElement? {
        let systemWideElement = AXUIElementCreateSystemWide()

        var focusedApp: AnyObject?
        guard AXUIElementCopyAttributeValue(systemWideElement, kAXFocusedApplicationAttribute as CFString, &focusedApp) == .success,
              let focusedAppElement = focusedApp as! AXUIElement? else {
            return nil
        }

        var focusedElement: AnyObject?
        guard AXUIElementCopyAttributeValue(focusedAppElement, kAXFocusedUIElementAttribute as CFString, &focusedElement) == .success,
              let element = focusedElement as! AXUIElement? else {
            return nil
        }

        return element
    }

    private func insertAtSelection(_ element: AXUIElement, text: String) -> Bool {
        // Get current value
        var currentValue: AnyObject?
        guard AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &currentValue) == .success,
              let currentString = currentValue as? String else {
            return false
        }

        // Get selected text range
        var selectedRange: AnyObject?
        guard AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &selectedRange) == .success else {
            // No selection, try appending
            let newValue = currentString + text
            let result = AXUIElementSetAttributeValue(element, kAXValueAttribute as CFString, newValue as CFTypeRef)
            return result == .success
        }

        // Try to set selected text
        let result = AXUIElementSetAttributeValue(element, kAXSelectedTextAttribute as CFString, text as CFTypeRef)
        return result == .success
    }

    private func insertViaClipboard(_ text: String) {
        clipboardManager.setString(text)

        // Simulate Cmd+V
        let source = CGEventSource(stateID: .hidSystemState)

        // Key down
        let keyDownEvent = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true) // 0x09 = V
        keyDownEvent?.flags = .maskCommand
        keyDownEvent?.post(tap: .cghidEventTap)

        // Key up
        let keyUpEvent = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
        keyUpEvent?.flags = .maskCommand
        keyUpEvent?.post(tap: .cghidEventTap)

        Logger.shared.debug("Paste simulated via CGEvent", component: "TextOutput")
    }
}
