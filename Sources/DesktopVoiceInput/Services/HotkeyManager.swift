import AppKit
import Combine
import Foundation

@MainActor
final class HotkeyManager {
    var onHoldPress: (() -> Void)?
    var onHoldRelease: (() -> Void)?
    var onTogglePress: (() -> Void)?

    private let settings: AppSettings
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var isHoldPressed = false
    private var isTogglePressed = false
    private var isSuspended = false
    private var isSessionActive = false

    init(settings: AppSettings) {
        self.settings = settings
    }

    func start() {
        stop()

        let mask = CGEventMask((1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue) | (1 << CGEventType.flagsChanged.rawValue) | (1 << CGEventType.tapDisabledByTimeout.rawValue) | (1 << CGEventType.tapDisabledByUserInput.rawValue))
        let unmanagedSelf = Unmanaged.passUnretained(self)
        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, refcon in
                guard let refcon else { return Unmanaged.passUnretained(event) }
                let manager = Unmanaged<HotkeyManager>.fromOpaque(refcon).takeUnretainedValue()

                if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                    manager.reenableTap()
                    return Unmanaged.passUnretained(event)
                }

                let shouldSuppress = manager.handle(event: event, type: type)
                return shouldSuppress ? nil : Unmanaged.passUnretained(event)
            },
            userInfo: unmanagedSelf.toOpaque()
        )

        guard let eventTap else { return }
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        self.runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
    }

    func reloadConfiguration() {
        let wasHoldPressed = isHoldPressed
        let wasSessionActive = isSessionActive

        start()

        if wasSessionActive && wasHoldPressed {
            isHoldPressed = true
        }
    }

    func notifySessionStarted() {
        isSessionActive = true
    }

    func notifySessionEnded() {
        isSessionActive = false
    }

    func suspend() {
        isSuspended = true
        isHoldPressed = false
        isTogglePressed = false
    }

    func resume() {
        isSuspended = false
    }

    func stop() {
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
            self.runLoopSource = nil
        }

        if let eventTap {
            CFMachPortInvalidate(eventTap)
            self.eventTap = nil
        }

        isHoldPressed = false
        isTogglePressed = false
    }

    private func reenableTap() {
        guard let eventTap else { return }
        CGEvent.tapEnable(tap: eventTap, enable: true)
    }

    private func handle(event: CGEvent, type: CGEventType) -> Bool {
        guard !isSuspended else { return false }

        let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = NSEvent.ModifierFlags(rawValue: UInt(event.flags.rawValue)).intersection([.command, .option, .control, .shift, .function])
        let holdHotkey = settings.holdToTalkHotkey
        let toggleHotkey = settings.toggleToTalkHotkey

        // Fn 键（keyCode 63）在 flagsChanged 中单独处理，这里跳过
        let matchesHoldKeyCode = settings.holdToTalkEnabled && keyCode == holdHotkey.keyCode && keyCode != 63
        let matchesHoldModifiers = settings.holdToTalkEnabled && matchModifiers(flags, against: holdHotkey.modifiers)
        let matchesToggleKeyCode = settings.toggleToTalkEnabled && keyCode == toggleHotkey.keyCode && keyCode != 63
        let matchesToggleModifiers = settings.toggleToTalkEnabled && matchModifiers(flags, against: toggleHotkey.modifiers)

        switch type {
        case .keyDown:
            if matchesToggleKeyCode, matchesToggleModifiers {
                if !isTogglePressed {
                    isTogglePressed = true
                    onTogglePress?()
                }
                return true
            }

            if matchesHoldKeyCode, matchesHoldModifiers {
                if !isHoldPressed {
                    isHoldPressed = true
                    onHoldPress?()
                }
                return true
            }

            return false
        case .keyUp:
            var shouldSuppress = false

            if isTogglePressed, keyCode == toggleHotkey.keyCode, toggleHotkey.keyCode != 63 {
                isTogglePressed = false
                shouldSuppress = true
            }

            if isHoldPressed, keyCode == holdHotkey.keyCode, holdHotkey.keyCode != 63 {
                isHoldPressed = false
                onHoldRelease?()
                shouldSuppress = true
            }

            return shouldSuppress
        case .flagsChanged:
            // 处理修饰键作为单键的情况
            let modifierKeyMap: [(keyCode: UInt16, flag: NSEvent.ModifierFlags)] = [
                (63, .function),   // Fn
                (59, .control),    // Left Control
                (62, .control),    // Right Control
                (58, .option),     // Left Option
                (61, .option),     // Right Option
                (55, .command),    // Left Command
                (54, .command),    // Right Command
                (56, .shift),      // Left Shift
                (60, .shift)       // Right Shift
            ]

            for (keyCode, flag) in modifierKeyMap {
                // Toggle mode
                if settings.toggleToTalkEnabled, toggleHotkey.keyCode == keyCode {
                    if flags.contains(flag), !isTogglePressed {
                        isTogglePressed = true
                        onTogglePress?()
                        return true
                    } else if !flags.contains(flag), isTogglePressed {
                        isTogglePressed = false
                        return true
                    }
                }

                // Hold mode
                if settings.holdToTalkEnabled, holdHotkey.keyCode == keyCode {
                    if flags.contains(flag), !isHoldPressed {
                        isHoldPressed = true
                        onHoldPress?()
                        return true
                    } else if !flags.contains(flag), isHoldPressed {
                        isHoldPressed = false
                        onHoldRelease?()
                        return true
                    }
                }
            }

            return false
        default:
            return false
        }
    }

    private func matchModifiers(_ actual: NSEvent.ModifierFlags, against expected: NSEvent.ModifierFlags) -> Bool {
        if expected.isEmpty {
            return actual.isEmpty
        }
        return actual.isSuperset(of: expected)
    }
}
