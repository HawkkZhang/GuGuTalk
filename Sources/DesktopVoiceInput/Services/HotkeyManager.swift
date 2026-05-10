import AppKit
import Combine
import Foundation
import os

@MainActor
final class HotkeyManager {
    private static let logger = Logger(subsystem: "com.end.DesktopVoiceInput", category: "HotkeyManager")

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
        guard eventTap == nil else {
            Self.logger.debug("Hotkey monitor start ignored because event tap is already active")
            return
        }

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
        Self.logger.info("Hotkey monitor started. hold=\(self.settings.holdToTalkHotkey.displayName, privacy: .public) toggle=\(self.settings.toggleToTalkHotkey.displayName, privacy: .public)")
    }

    func reloadConfiguration() {
        let wasHoldPressed = isHoldPressed
        let wasSessionActive = isSessionActive

        Self.logger.info("Reloading hotkey configuration. wasSessionActive=\(wasSessionActive, privacy: .public) wasHoldPressed=\(wasHoldPressed, privacy: .public)")
        stop()
        start()

        if wasSessionActive && wasHoldPressed {
            isHoldPressed = true
        }
    }

    func notifySessionStarted() {
        isSessionActive = true
        Self.logger.debug("Hotkey manager notified that capture session started")
    }

    func notifySessionEnded() {
        isSessionActive = false
        Self.logger.debug("Hotkey manager notified that capture session ended")
    }

    func suspend() {
        isSuspended = true
        isHoldPressed = false
        isTogglePressed = false
        Self.logger.info("Hotkey monitor suspended")
    }

    func resume() {
        isSuspended = false
        Self.logger.info("Hotkey monitor resumed")
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
        Self.logger.info("Hotkey monitor stopped")
    }

    private func reenableTap() {
        guard let eventTap else { return }
        Self.logger.warning("Hotkey event tap was disabled by macOS; re-enabling")
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
        let matchesHoldModifiers = settings.holdToTalkEnabled && matchModifiersExactly(flags, against: holdHotkey.modifiers)
        let matchesToggleKeyCode = settings.toggleToTalkEnabled && keyCode == toggleHotkey.keyCode && keyCode != 63
        let matchesToggleModifiers = settings.toggleToTalkEnabled && matchModifiersExactly(flags, against: toggleHotkey.modifiers)

        switch type {
        case .keyDown:
            if matchesToggleKeyCode, matchesToggleModifiers {
                if !isTogglePressed {
                    isTogglePressed = true
                    Self.logger.info("Toggle hotkey pressed. keyCode=\(keyCode, privacy: .public) flags=\(self.describe(flags), privacy: .public)")
                    onTogglePress?()
                }
                return true
            }

            if matchesHoldKeyCode, matchesHoldModifiers {
                if !isHoldPressed {
                    isHoldPressed = true
                    Self.logger.info("Hold hotkey pressed. keyCode=\(keyCode, privacy: .public) flags=\(self.describe(flags), privacy: .public)")
                    onHoldPress?()
                }
                return true
            }

            return false
        case .keyUp:
            var shouldSuppress = false

            if isTogglePressed, keyCode == toggleHotkey.keyCode, toggleHotkey.keyCode != 63 {
                isTogglePressed = false
                Self.logger.info("Toggle hotkey released. keyCode=\(keyCode, privacy: .public) flags=\(self.describe(flags), privacy: .public)")
                shouldSuppress = true
            }

            if isHoldPressed, keyCode == holdHotkey.keyCode, holdHotkey.keyCode != 63 {
                isHoldPressed = false
                Self.logger.info("Hold hotkey released. keyCode=\(keyCode, privacy: .public) flags=\(self.describe(flags), privacy: .public)")
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
                    let isShortcutActive = modifierShortcutIsActive(flags: flags, triggerFlag: flag, hotkey: toggleHotkey)
                    if isShortcutActive, !isTogglePressed {
                        isTogglePressed = true
                        Self.logger.info("Modifier toggle hotkey pressed. keyCode=\(keyCode, privacy: .public) flags=\(self.describe(flags), privacy: .public)")
                        onTogglePress?()
                        return true
                    } else if !isShortcutActive, isTogglePressed {
                        isTogglePressed = false
                        Self.logger.info("Modifier toggle hotkey released. keyCode=\(keyCode, privacy: .public) flags=\(self.describe(flags), privacy: .public)")
                        return true
                    }
                }

                // Hold mode
                if settings.holdToTalkEnabled, holdHotkey.keyCode == keyCode {
                    let isShortcutActive = modifierShortcutIsActive(flags: flags, triggerFlag: flag, hotkey: holdHotkey)
                    if isShortcutActive, !isHoldPressed {
                        isHoldPressed = true
                        Self.logger.info("Modifier hold hotkey pressed. keyCode=\(keyCode, privacy: .public) flags=\(self.describe(flags), privacy: .public)")
                        onHoldPress?()
                        return true
                    } else if !isShortcutActive, isHoldPressed {
                        isHoldPressed = false
                        Self.logger.info("Modifier hold hotkey released. keyCode=\(keyCode, privacy: .public) flags=\(self.describe(flags), privacy: .public)")
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

    private func modifierShortcutIsActive(
        flags: NSEvent.ModifierFlags,
        triggerFlag: NSEvent.ModifierFlags,
        hotkey: HotkeyConfiguration
    ) -> Bool {
        let expectedFlags = hotkey.modifiers.union(triggerFlag)
        return matchModifiersExactly(flags, against: expectedFlags)
    }

    private func matchModifiersExactly(_ actual: NSEvent.ModifierFlags, against expected: NSEvent.ModifierFlags) -> Bool {
        actual.intersection(Self.supportedModifierMask) == expected.intersection(Self.supportedModifierMask)
    }

    private func describe(_ flags: NSEvent.ModifierFlags) -> String {
        var parts: [String] = []
        if flags.contains(.control) { parts.append("control") }
        if flags.contains(.option) { parts.append("option") }
        if flags.contains(.shift) { parts.append("shift") }
        if flags.contains(.command) { parts.append("command") }
        if flags.contains(.function) { parts.append("function") }
        return parts.isEmpty ? "none" : parts.joined(separator: "+")
    }

    private static let supportedModifierMask: NSEvent.ModifierFlags = [.command, .option, .control, .shift, .function]
}
