import AppKit
import ApplicationServices
import Foundation
import os

@MainActor
final class TextInsertionService {
    private static let logger = Logger(subsystem: "com.desktopvoiceinput", category: "TextInsertion")

    func insert(text: String) -> InsertionResult {
        let frontmostApplication = NSWorkspace.shared.frontmostApplication
        let targetApp = frontmostApplication?.localizedName
        let targetBundleID = frontmostApplication?.bundleIdentifier

        Self.logger.info("开始插入文本，目标应用: \(targetApp ?? "未知", privacy: .public)，文本长度: \(text.count)")

        if targetBundleID == Bundle.main.bundleIdentifier, !focusedElementLooksEditable() {
            Self.logger.warning("目标是自己的窗口，但焦点不是可输入控件，拒绝插入")
            return InsertionResult(
                method: .failed,
                targetAppName: targetApp,
                succeeded: false,
                failureReason: "当前焦点不在可输入区域。请先点进 GuGuTalk 的文本框或切到目标应用。"
            )
        }

        Self.logger.info("尝试方法 1: 剪贴板粘贴")
        if clipboardPasteInsertion(text: text) {
            Self.logger.info("✓ 剪贴板粘贴成功")
            return InsertionResult(method: .clipboardPaste, targetAppName: targetApp, succeeded: true, failureReason: nil)
        }
        Self.logger.warning("✗ 剪贴板粘贴失败")

        Self.logger.info("尝试方法 2: Accessibility API")
        if let result = accessibilityInsertion(text: text, targetApp: targetApp) {
            Self.logger.info("✓ Accessibility 插入成功")
            return result
        }
        Self.logger.warning("✗ Accessibility 插入失败")

        Self.logger.info("尝试方法 3: 模拟键盘输入")
        if simulatedKeyboardInsertion(text: text) {
            Self.logger.info("✓ 模拟键盘成功")
            return InsertionResult(method: .simulatedKeyboard, targetAppName: targetApp, succeeded: true, failureReason: nil)
        }
        Self.logger.error("✗ 所有插入方法都失败")

        return InsertionResult(method: .failed, targetAppName: targetApp, succeeded: false, failureReason: "无法写入当前应用，请手动复制预览文本。")
    }

    private func accessibilityInsertion(text: String, targetApp: String?) -> InsertionResult? {
        guard AXIsProcessTrusted() else { return nil }

        guard let focusedElement = focusedElement() else {
            return nil
        }

        var valueObject: AnyObject?
        let valueResult = AXUIElementCopyAttributeValue(focusedElement, kAXValueAttribute as CFString, &valueObject)
        guard valueResult == .success, let currentValue = valueObject as? String else { return nil }
        let editableValue = normalizedEditableValue(currentValue, from: focusedElement)

        var selectedRangeObject: AnyObject?
        let selectionResult = AXUIElementCopyAttributeValue(focusedElement, kAXSelectedTextRangeAttribute as CFString, &selectedRangeObject)
        guard selectionResult == .success, let rangeValue = selectedRangeObject else { return nil }

        var selectedRange = CFRange()
        guard AXValueGetValue(rangeValue as! AXValue, .cfRange, &selectedRange) else { return nil }

        let safeRange = clampedRange(selectedRange, in: editableValue)
        guard let stringRange = Range(NSRange(location: safeRange.location, length: safeRange.length), in: editableValue) else { return nil }

        let merged = editableValue.replacingCharacters(in: stringRange, with: text)
        let cursorLocation = safeRange.location + text.count

        guard AXUIElementSetAttributeValue(focusedElement, kAXValueAttribute as CFString, merged as CFTypeRef) == .success else {
            return nil
        }

        var newRange = CFRange(location: cursorLocation, length: 0)
        guard let newRangeValue = AXValueCreate(.cfRange, &newRange) else {
            return nil
        }

        AXUIElementSetAttributeValue(focusedElement, kAXSelectedTextRangeAttribute as CFString, newRangeValue)
        return InsertionResult(method: .accessibility, targetAppName: targetApp, succeeded: true, failureReason: nil)
    }

    private func focusedElement() -> AXUIElement? {
        guard AXIsProcessTrusted() else { return nil }

        let systemWide = AXUIElementCreateSystemWide()
        var focusedObject: AnyObject?
        let focusedResult = AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &focusedObject)
        guard focusedResult == .success, let focusedObject else { return nil }
        return unsafeDowncast(focusedObject, to: AXUIElement.self)
    }

    private func focusedElementLooksEditable() -> Bool {
        guard let focusedElement = focusedElement() else { return false }

        var roleObject: AnyObject?
        let roleResult = AXUIElementCopyAttributeValue(focusedElement, kAXRoleAttribute as CFString, &roleObject)
        let role = roleResult == .success ? roleObject as? String : nil

        let editableRoles: Set<String> = [
            kAXTextFieldRole as String,
            kAXTextAreaRole as String,
            kAXComboBoxRole as String
        ]
        if let role, editableRoles.contains(role) {
            return true
        }

        var settableObject: DarwinBoolean = false
        let settableResult = AXUIElementIsAttributeSettable(focusedElement, kAXValueAttribute as CFString, &settableObject)
        if settableResult == .success, settableObject.boolValue {
            return true
        }

        var selectedRangeObject: AnyObject?
        let selectedRangeResult = AXUIElementCopyAttributeValue(focusedElement, kAXSelectedTextRangeAttribute as CFString, &selectedRangeObject)
        return selectedRangeResult == .success
    }

    private func normalizedEditableValue(_ currentValue: String, from element: AXUIElement) -> String {
        var placeholderObject: AnyObject?
        let placeholderResult = AXUIElementCopyAttributeValue(element, kAXPlaceholderValueAttribute as CFString, &placeholderObject)
        guard placeholderResult == .success,
              let placeholder = placeholderObject as? String,
              !placeholder.isEmpty,
              currentValue == placeholder else {
            return currentValue
        }

        return ""
    }

    private func clampedRange(_ range: CFRange, in text: String) -> CFRange {
        let upperBound = text.utf16.count
        let location = max(0, min(range.location, upperBound))
        let length = max(0, min(range.length, upperBound - location))
        return CFRange(location: location, length: length)
    }

    private func simulatedKeyboardInsertion(text: String) -> Bool {
        guard AXIsProcessTrusted() else { return false }

        let source = CGEventSource(stateID: .combinedSessionState)
        for scalar in text.unicodeScalars {
            guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
                  let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) else {
                return false
            }

            var utf16 = Array(String(scalar).utf16)
            keyDown.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: &utf16)
            keyUp.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: &utf16)
            keyDown.post(tap: .cghidEventTap)
            keyUp.post(tap: .cghidEventTap)
        }

        return true
    }

    private func clipboardPasteInsertion(text: String) -> Bool {
        let pasteboard = NSPasteboard.general
        let savedContents = PasteboardSnapshot(pasteboard: pasteboard)

        pasteboard.clearContents()
        guard pasteboard.setString(text, forType: .string) else {
            savedContents.restore(to: pasteboard)
            return false
        }

        let changeCountAfterSet = pasteboard.changeCount

        guard let source = CGEventSource(stateID: .combinedSessionState),
              let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false) else {
            savedContents.restore(to: pasteboard)
            return false
        }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            guard pasteboard.changeCount == changeCountAfterSet else { return }
            savedContents.restore(to: pasteboard)
        }

        return true
    }
}

private struct PasteboardSnapshot {
    private let items: [[NSPasteboard.PasteboardType: Data]]

    init(pasteboard: NSPasteboard) {
        var snapshot: [[NSPasteboard.PasteboardType: Data]] = []
        for item in pasteboard.pasteboardItems ?? [] {
            var entry: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types {
                if let data = item.data(forType: type) {
                    entry[type] = data
                }
            }
            if !entry.isEmpty {
                snapshot.append(entry)
            }
        }
        self.items = snapshot
    }

    func restore(to pasteboard: NSPasteboard) {
        pasteboard.clearContents()
        guard !items.isEmpty else { return }
        let pasteboardItems = items.map { entry -> NSPasteboardItem in
            let item = NSPasteboardItem()
            for (type, data) in entry {
                item.setData(data, forType: type)
            }
            return item
        }
        pasteboard.writeObjects(pasteboardItems)
    }
}
