import Foundation
import Carbon.HIToolbox

struct ShortcutConfiguration: Codable, Equatable, Sendable {
    var keyCode: UInt16
    var modifiers: UInt64

    static let rightCommand = ShortcutConfiguration(
        keyCode: UInt16(kVK_RightCommand),
        modifiers: 0
    )

    static let leftCommand = ShortcutConfiguration(
        keyCode: UInt16(kVK_Command),
        modifiers: 0
    )

    var displayName: String {
        var parts: [String] = []

        // Add modifier names
        let modifierFlags = CGEventFlags(rawValue: modifiers)
        if modifierFlags.contains(.maskControl) { parts.append("Control") }
        if modifierFlags.contains(.maskAlternate) { parts.append("Option") }
        if modifierFlags.contains(.maskShift) { parts.append("Shift") }
        if modifierFlags.contains(.maskCommand) { parts.append("Command") }

        // Add key name
        parts.append(keyCodeToString(keyCode))

        return parts.joined(separator: " + ")
    }

    private func keyCodeToString(_ keyCode: UInt16) -> String {
        switch Int(keyCode) {
        case kVK_RightCommand: return "Right Command"
        case kVK_Command: return "Left Command"
        case kVK_RightControl: return "Right Control"
        case kVK_Control: return "Left Control"
        case kVK_RightOption: return "Right Option"
        case kVK_Option: return "Left Option"
        case kVK_RightShift: return "Right Shift"
        case kVK_Shift: return "Left Shift"
        case kVK_CapsLock: return "Caps Lock"
        case kVK_Function: return "Fn"
        case kVK_Space: return "Space"
        case kVK_Return: return "Return"
        case kVK_Tab: return "Tab"
        case kVK_Escape: return "Escape"
        case kVK_Delete: return "Delete"
        case kVK_ForwardDelete: return "Forward Delete"
        default:
            // Try to get character for regular keys
            if let char = keyCodeToCharacter(keyCode) {
                return char.uppercased()
            }
            return "Key \(keyCode)"
        }
    }

    private func keyCodeToCharacter(_ keyCode: UInt16) -> String? {
        let source = TISCopyCurrentKeyboardInputSource().takeRetainedValue()
        guard let layoutData = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else {
            return nil
        }

        let dataRef = unsafeBitCast(layoutData, to: CFData.self)
        let keyboardLayout = unsafeBitCast(CFDataGetBytePtr(dataRef), to: UnsafePointer<UCKeyboardLayout>.self)

        var deadKeyState: UInt32 = 0
        var chars = [UniChar](repeating: 0, count: 4)
        var length: Int = 0

        let result = UCKeyTranslate(
            keyboardLayout,
            keyCode,
            UInt16(kUCKeyActionDisplay),
            0,
            UInt32(LMGetKbdType()),
            OptionBits(kUCKeyTranslateNoDeadKeysBit),
            &deadKeyState,
            4,
            &length,
            &chars
        )

        guard result == noErr, length > 0 else { return nil }
        return String(utf16CodeUnits: chars, count: length)
    }
}
