import Foundation
import Cocoa
import Carbon.HIToolbox

protocol KeyEventMonitorDelegate: AnyObject {
    func keyEventMonitor(_ monitor: KeyEventMonitor, didDetectKeyDown keyCode: UInt16, flags: CGEventFlags)
    func keyEventMonitor(_ monitor: KeyEventMonitor, didDetectKeyUp keyCode: UInt16, flags: CGEventFlags)
    func keyEventMonitorDidDetectOtherKey(_ monitor: KeyEventMonitor)
}

final class KeyEventMonitor {
    weak var delegate: KeyEventMonitorDelegate?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var isMonitoring = false

    private let targetKeyCode: UInt16
    private var isTargetKeyDown = false

    init(targetKeyCode: UInt16) {
        self.targetKeyCode = targetKeyCode
    }

    deinit {
        stop()
    }

    func start() -> Bool {
        guard !isMonitoring else { return true }

        // Create event mask for key events and flags changed (for modifier keys)
        let eventMask: CGEventMask = (1 << CGEventType.keyDown.rawValue) |
                                      (1 << CGEventType.keyUp.rawValue) |
                                      (1 << CGEventType.flagsChanged.rawValue)

        // Create callback
        let callback: CGEventTapCallBack = { proxy, type, event, refcon in
            guard let refcon = refcon else { return Unmanaged.passUnretained(event) }

            let monitor = Unmanaged<KeyEventMonitor>.fromOpaque(refcon).takeUnretainedValue()
            return monitor.handleEvent(proxy: proxy, type: type, event: event)
        }

        // Create event tap
        let selfPointer = Unmanaged.passUnretained(self).toOpaque()
        guard let eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: callback,
            userInfo: selfPointer
        ) else {
            Logger.shared.error("Failed to create event tap - accessibility permission may be required", component: "KeyEventMonitor")
            return false
        }

        self.eventTap = eventTap

        // Create run loop source
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)

        // Enable the event tap
        CGEvent.tapEnable(tap: eventTap, enable: true)

        isMonitoring = true
        Logger.shared.info("Key event monitoring started", component: "KeyEventMonitor")
        return true
    }

    func stop() {
        guard isMonitoring else { return }

        if let eventTap = eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }

        if let runLoopSource = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        }

        eventTap = nil
        runLoopSource = nil
        isMonitoring = false
        isTargetKeyDown = false

        Logger.shared.info("Key event monitoring stopped", component: "KeyEventMonitor")
    }

    func updateTargetKeyCode(_ keyCode: UInt16) {
        // This would require recreating the monitor with a new key code
        // For simplicity, we'll handle this in the ShortcutManager
    }

    private func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // Handle tap disabled (system can disable taps)
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let eventTap = eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = event.flags

        // Check if this is our target key (modifier key handling via flagsChanged)
        if type == .flagsChanged {
            let isModifierKey = isModifierKeyCode(keyCode)

            if isModifierKey && keyCode == targetKeyCode {
                // Check if the modifier is now pressed or released
                let isPressed = isModifierPressed(keyCode: keyCode, flags: flags)

                if isPressed && !isTargetKeyDown {
                    isTargetKeyDown = true
                    delegate?.keyEventMonitor(self, didDetectKeyDown: keyCode, flags: flags)
                } else if !isPressed && isTargetKeyDown {
                    isTargetKeyDown = false
                    delegate?.keyEventMonitor(self, didDetectKeyUp: keyCode, flags: flags)
                }
            }
        } else if type == .keyDown {
            // Regular key pressed
            if keyCode == targetKeyCode && !isModifierKeyCode(keyCode) {
                if !isTargetKeyDown {
                    isTargetKeyDown = true
                    delegate?.keyEventMonitor(self, didDetectKeyDown: keyCode, flags: flags)
                }
            } else if isTargetKeyDown {
                // Another key pressed while holding target - signal cancellation
                delegate?.keyEventMonitorDidDetectOtherKey(self)
            }
        } else if type == .keyUp {
            if keyCode == targetKeyCode && !isModifierKeyCode(keyCode) {
                if isTargetKeyDown {
                    isTargetKeyDown = false
                    delegate?.keyEventMonitor(self, didDetectKeyUp: keyCode, flags: flags)
                }
            }
        }

        // Pass through all events unchanged
        return Unmanaged.passUnretained(event)
    }

    private func isModifierKeyCode(_ keyCode: UInt16) -> Bool {
        switch Int(keyCode) {
        case kVK_Command, kVK_RightCommand,
             kVK_Shift, kVK_RightShift,
             kVK_Option, kVK_RightOption,
             kVK_Control, kVK_RightControl,
             kVK_CapsLock, kVK_Function:
            return true
        default:
            return false
        }
    }

    private func isModifierPressed(keyCode: UInt16, flags: CGEventFlags) -> Bool {
        switch Int(keyCode) {
        case kVK_Command, kVK_RightCommand:
            return flags.contains(.maskCommand)
        case kVK_Shift, kVK_RightShift:
            return flags.contains(.maskShift)
        case kVK_Option, kVK_RightOption:
            return flags.contains(.maskAlternate)
        case kVK_Control, kVK_RightControl:
            return flags.contains(.maskControl)
        case kVK_CapsLock:
            return flags.contains(.maskAlphaShift)
        default:
            return false
        }
    }
}
