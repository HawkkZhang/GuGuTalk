import AppKit
import ApplicationServices
import Foundation

@MainActor
final class TextInsertionService {
    func insert(text: String) -> InsertionResult {
        let frontmostApplication = NSWorkspace.shared.frontmostApplication
        let targetApp = frontmostApplication?.localizedName

        if frontmostApplication?.bundleIdentifier == Bundle.main.bundleIdentifier {
            return InsertionResult(
                method: .failed,
                targetAppName: targetApp,
                succeeded: false,
                failureReason: "当前焦点还在 Desktop Voice Input 自己的窗口里。为了避免把识别结果写坏设置项，这次不会自动插入。请先切到目标应用再说话。"
            )
        }

        if let result = accessibilityInsertion(text: text, targetApp: targetApp) {
            return result
        }

        if simulatedKeyboardInsertion(text: text) {
            return InsertionResult(method: .simulatedKeyboard, targetAppName: targetApp, succeeded: true, failureReason: nil)
        }

        if clipboardFallbackInsertion(text: text) {
            return InsertionResult(method: .clipboardPaste, targetAppName: targetApp, succeeded: true, failureReason: nil)
        }

        return InsertionResult(method: .failed, targetAppName: targetApp, succeeded: false, failureReason: "无法写入当前应用，请手动复制预览文本。")
    }

    private func accessibilityInsertion(text: String, targetApp: String?) -> InsertionResult? {
        guard AXIsProcessTrusted() else { return nil }

        let systemWide = AXUIElementCreateSystemWide()
        var focusedObject: AnyObject?
        let focusedResult = AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &focusedObject)

        guard focusedResult == .success, let focusedElement = focusedObject.map({ unsafeDowncast($0, to: AXUIElement.self) }) else {
            return nil
        }

        var valueObject: AnyObject?
        let valueResult = AXUIElementCopyAttributeValue(focusedElement, kAXValueAttribute as CFString, &valueObject)
        guard valueResult == .success, let currentValue = valueObject as? String else { return nil }

        var selectedRangeObject: AnyObject?
        let selectionResult = AXUIElementCopyAttributeValue(focusedElement, kAXSelectedTextRangeAttribute as CFString, &selectedRangeObject)
        guard selectionResult == .success, let rangeValue = selectedRangeObject else { return nil }

        var selectedRange = CFRange()
        guard AXValueGetValue(rangeValue as! AXValue, .cfRange, &selectedRange) else { return nil }

        guard let stringRange = Range(NSRange(location: selectedRange.location, length: selectedRange.length), in: currentValue) else { return nil }

        let merged = currentValue.replacingCharacters(in: stringRange, with: text)
        let cursorLocation = selectedRange.location + text.count

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

    private func clipboardFallbackInsertion(text: String) -> Bool {
        let pasteboard = NSPasteboard.general
        let originalString = pasteboard.string(forType: .string)

        pasteboard.clearContents()
        guard pasteboard.setString(text, forType: .string) else { return false }

        defer {
            pasteboard.clearContents()
            if let originalString {
                pasteboard.setString(originalString, forType: .string)
            }
        }

        guard let source = CGEventSource(stateID: .combinedSessionState),
              let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false) else {
            return false
        }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
        return true
    }
}
