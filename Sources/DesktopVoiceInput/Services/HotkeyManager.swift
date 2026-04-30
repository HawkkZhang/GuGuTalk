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

    init(settings: AppSettings) {
        self.settings = settings
    }

    func start() {
        stop()

        let mask = CGEventMask((1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue) | (1 << CGEventType.flagsChanged.rawValue))
        let unmanagedSelf = Unmanaged.passUnretained(self)
        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, refcon in
                guard let refcon else { return Unmanaged.passUnretained(event) }
                let manager = Unmanaged<HotkeyManager>.fromOpaque(refcon).takeUnretainedValue()
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
        start()
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

    private func handle(event: CGEvent, type: CGEventType) -> Bool {
        guard !isSuspended else { return false }

        let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = NSEvent.ModifierFlags(rawValue: UInt(event.flags.rawValue)).intersection([.command, .option, .control, .shift, .function])
        let holdHotkey = settings.holdToTalkHotkey
        let toggleHotkey = settings.toggleToTalkHotkey

        let matchesHoldKeyCode = settings.holdToTalkEnabled && keyCode == holdHotkey.keyCode
        let matchesHoldModifiers = settings.holdToTalkEnabled && flags == holdHotkey.modifiers
        let matchesToggleKeyCode = settings.toggleToTalkEnabled && keyCode == toggleHotkey.keyCode
        let matchesToggleModifiers = settings.toggleToTalkEnabled && flags == toggleHotkey.modifiers

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
            if settings.toggleToTalkEnabled, toggleHotkey.keyCode == 63 {
                if flags.contains(.function), !isTogglePressed {
                    isTogglePressed = true
                    onTogglePress?()
                    return true
                } else if !flags.contains(.function), isTogglePressed {
                    isTogglePressed = false
                    return true
                }
            }

            if settings.holdToTalkEnabled, holdHotkey.keyCode == 63 {
                if flags.contains(.function), !isHoldPressed {
                    isHoldPressed = true
                    onHoldPress?()
                    return true
                } else if !flags.contains(.function), isHoldPressed {
                    isHoldPressed = false
                    onHoldRelease?()
                    return true
                }
            }
            return false
        default:
            return false
        }
    }
}
