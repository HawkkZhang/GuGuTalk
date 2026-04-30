import AppKit
import Combine
import Foundation
import SwiftUI

@MainActor
final class AppSettings: ObservableObject {
    enum Keys {
        static let preferredMode = "preferredMode"
        static let hotkeyPreset = "hotkeyPreset"
        static let hotkeyKeyCode = "hotkeyKeyCode"
        static let hotkeyModifiers = "hotkeyModifiers"
        static let holdToTalkHotkeyKeyCode = "holdToTalkHotkeyKeyCode"
        static let holdToTalkHotkeyModifiers = "holdToTalkHotkeyModifiers"
        static let holdToTalkEnabled = "holdToTalkEnabled"
        static let toggleToTalkHotkeyKeyCode = "toggleToTalkHotkeyKeyCode"
        static let toggleToTalkHotkeyModifiers = "toggleToTalkHotkeyModifiers"
        static let toggleToTalkEnabled = "toggleToTalkEnabled"
        static let doubaoAppID = "doubaoAppID"
        static let doubaoAccessKey = "doubaoAccessKey"
        static let doubaoResourceID = "doubaoResourceID"
        static let doubaoEndpoint = "doubaoEndpoint"
        static let legacyDoubaoToken = "doubaoToken"
        static let legacyDoubaoCluster = "doubaoCluster"
        static let qwenAPIKey = "qwenAPIKey"
        static let qwenModel = "qwenModel"
        static let qwenEndpoint = "qwenEndpoint"
        static let appearancePreference = "appearancePreference"
    }

    @Published var preferredMode: RecognitionMode {
        didSet { defaults.set(preferredMode.rawValue, forKey: Keys.preferredMode) }
    }

    @Published var holdToTalkHotkey: HotkeyConfiguration {
        didSet {
            defaults.set(Int(holdToTalkHotkey.keyCode), forKey: Keys.holdToTalkHotkeyKeyCode)
            defaults.set(Int(holdToTalkHotkey.modifiers.rawValue), forKey: Keys.holdToTalkHotkeyModifiers)
            defaults.set(Int(holdToTalkHotkey.keyCode), forKey: Keys.hotkeyKeyCode)
            defaults.set(Int(holdToTalkHotkey.modifiers.rawValue), forKey: Keys.hotkeyModifiers)
        }
    }

    @Published var holdToTalkEnabled: Bool {
        didSet { defaults.set(holdToTalkEnabled, forKey: Keys.holdToTalkEnabled) }
    }

    @Published var toggleToTalkHotkey: HotkeyConfiguration {
        didSet {
            defaults.set(Int(toggleToTalkHotkey.keyCode), forKey: Keys.toggleToTalkHotkeyKeyCode)
            defaults.set(Int(toggleToTalkHotkey.modifiers.rawValue), forKey: Keys.toggleToTalkHotkeyModifiers)
        }
    }

    @Published var toggleToTalkEnabled: Bool {
        didSet { defaults.set(toggleToTalkEnabled, forKey: Keys.toggleToTalkEnabled) }
    }

    @Published var doubaoAppID: String {
        didSet { defaults.set(doubaoAppID, forKey: Keys.doubaoAppID) }
    }

    @Published var doubaoAccessKey: String {
        didSet { defaults.set(doubaoAccessKey, forKey: Keys.doubaoAccessKey) }
    }

    @Published var doubaoResourceID: String {
        didSet { defaults.set(doubaoResourceID, forKey: Keys.doubaoResourceID) }
    }

    @Published var doubaoEndpoint: String {
        didSet { defaults.set(doubaoEndpoint, forKey: Keys.doubaoEndpoint) }
    }

    @Published var qwenAPIKey: String {
        didSet { defaults.set(qwenAPIKey, forKey: Keys.qwenAPIKey) }
    }

    @Published var qwenModel: String {
        didSet { defaults.set(qwenModel, forKey: Keys.qwenModel) }
    }

    @Published var qwenEndpoint: String {
        didSet { defaults.set(qwenEndpoint, forKey: Keys.qwenEndpoint) }
    }

    @Published var appearancePreference: AppearancePreference {
        didSet { defaults.set(appearancePreference.rawValue, forKey: Keys.appearancePreference) }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let storedMode = RecognitionMode(rawValue: defaults.string(forKey: Keys.preferredMode) ?? "") ?? .local
        self.preferredMode = storedMode == .auto ? .local : storedMode
        if defaults.object(forKey: Keys.holdToTalkHotkeyKeyCode) != nil {
            let keyCode = UInt16(defaults.integer(forKey: Keys.holdToTalkHotkeyKeyCode))
            let modifiers = NSEvent.ModifierFlags(rawValue: UInt(defaults.integer(forKey: Keys.holdToTalkHotkeyModifiers)))
            self.holdToTalkHotkey = HotkeyConfiguration.make(keyCode: keyCode, modifiers: modifiers)
        } else if defaults.object(forKey: Keys.hotkeyKeyCode) != nil {
            let keyCode = UInt16(defaults.integer(forKey: Keys.hotkeyKeyCode))
            let modifiers = NSEvent.ModifierFlags(rawValue: UInt(defaults.integer(forKey: Keys.hotkeyModifiers)))
            self.holdToTalkHotkey = HotkeyConfiguration.make(keyCode: keyCode, modifiers: modifiers)
        } else {
            let legacyPreset = HotkeyPreset(rawValue: defaults.string(forKey: Keys.hotkeyPreset) ?? "") ?? .optionSpace
            self.holdToTalkHotkey = legacyPreset.configuration
        }
        self.holdToTalkEnabled = defaults.object(forKey: Keys.holdToTalkEnabled) == nil
            ? true
            : defaults.bool(forKey: Keys.holdToTalkEnabled)
        if defaults.object(forKey: Keys.toggleToTalkHotkeyKeyCode) != nil {
            let keyCode = UInt16(defaults.integer(forKey: Keys.toggleToTalkHotkeyKeyCode))
            let modifiers = NSEvent.ModifierFlags(rawValue: UInt(defaults.integer(forKey: Keys.toggleToTalkHotkeyModifiers)))
            self.toggleToTalkHotkey = HotkeyConfiguration.make(keyCode: keyCode, modifiers: modifiers)
        } else {
            self.toggleToTalkHotkey = HotkeyConfiguration.make(keyCode: 36, modifiers: [.option])
        }
        self.toggleToTalkEnabled = defaults.object(forKey: Keys.toggleToTalkEnabled) == nil
            ? true
            : defaults.bool(forKey: Keys.toggleToTalkEnabled)
        self.doubaoAppID = defaults.string(forKey: Keys.doubaoAppID) ?? ""
        self.doubaoAccessKey = defaults.string(forKey: Keys.doubaoAccessKey) ?? defaults.string(forKey: Keys.legacyDoubaoToken) ?? ""
        let storedDoubaoResourceID = defaults.string(forKey: Keys.doubaoResourceID) ?? defaults.string(forKey: Keys.legacyDoubaoCluster) ?? "volc.bigasr.sauc.duration"
        self.doubaoResourceID = storedDoubaoResourceID == "volc.seedasr.sauc.duration" ? "volc.bigasr.sauc.duration" : storedDoubaoResourceID
        let storedDoubaoEndpoint = defaults.string(forKey: Keys.doubaoEndpoint) ?? "wss://openspeech.bytedance.com/api/v3/sauc/bigmodel_async"
        self.doubaoEndpoint = storedDoubaoEndpoint == "wss://openspeech.bytedance.com/api/v3/sauc/bigmodel_nostream"
            ? "wss://openspeech.bytedance.com/api/v3/sauc/bigmodel_async"
            : storedDoubaoEndpoint
        self.qwenAPIKey = defaults.string(forKey: Keys.qwenAPIKey) ?? ""
        let storedQwenModel = defaults.string(forKey: Keys.qwenModel) ?? "qwen3-asr-flash-realtime"
        self.qwenModel = storedQwenModel == "qwen3-asr-flash" ? "qwen3-asr-flash-realtime" : storedQwenModel
        self.qwenEndpoint = defaults.string(forKey: Keys.qwenEndpoint) ?? "wss://dashscope.aliyuncs.com/api-ws/v1/realtime"
        self.appearancePreference = AppearancePreference(rawValue: defaults.string(forKey: Keys.appearancePreference) ?? "") ?? .system
    }

    var recognitionConfig: RecognitionConfig {
        RecognitionConfig(
            languageCode: "zh-CN",
            sampleRate: 16_000,
            mode: preferredMode,
            partialResultsEnabled: true,
            endpointing: .voiceActivityDetection,
            doubaoCredentials: DoubaoCredentials(
                appID: doubaoAppID.trimmingCharacters(in: .whitespacesAndNewlines),
                accessKey: doubaoAccessKey.trimmingCharacters(in: .whitespacesAndNewlines),
                resourceID: doubaoResourceID.trimmingCharacters(in: .whitespacesAndNewlines),
                endpoint: doubaoEndpoint.trimmingCharacters(in: .whitespacesAndNewlines)
            ),
            qwenCredentials: QwenCredentials(
                apiKey: qwenAPIKey.trimmingCharacters(in: .whitespacesAndNewlines),
                model: qwenModel.trimmingCharacters(in: .whitespacesAndNewlines),
                endpoint: qwenEndpoint.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        )
    }

    func validationIssue(for slot: HotkeySlot, candidate: HotkeyConfiguration) -> HotkeyValidationIssue? {
        let otherHotkey = slot == .holdToTalk ? toggleToTalkHotkey : holdToTalkHotkey
        if candidate.keyCode == otherHotkey.keyCode, candidate.modifiers == otherHotkey.modifiers {
            return HotkeyValidationIssue(severity: .error, message: "两种触发方式不能使用同一个快捷键，不然系统没法判断你是要按住说话还是切换开始/结束。")
        }

        return candidate.validationIssue
    }
}

enum AppearancePreference: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system:
            "跟随系统"
        case .light:
            "浅色"
        case .dark:
            "深色"
        }
    }

    @MainActor
    var colorScheme: ColorScheme? {
        switch self {
        case .system:
            Self.currentSystemColorScheme
        case .light:
            .light
        case .dark:
            .dark
        }
    }

    var nsAppearance: NSAppearance? {
        switch self {
        case .system:
            nil
        case .light:
            NSAppearance(named: .aqua)
        case .dark:
            NSAppearance(named: .darkAqua)
        }
    }

    @MainActor
    static var currentSystemColorScheme: ColorScheme {
        let appearance = NSApp.effectiveAppearance
        let match = appearance.bestMatch(from: [.aqua, .darkAqua])
        return match == .darkAqua ? .dark : .light
    }
}

enum HotkeySlot: String, Identifiable {
    case holdToTalk
    case toggleToTalk

    var id: String { rawValue }

    var title: String {
        switch self {
        case .holdToTalk:
            "按住说话"
        case .toggleToTalk:
            "按一下开始，再按停止"
        }
    }

    var subtitle: String {
        switch self {
        case .holdToTalk:
            "按下开始录音，松开立刻结束并整理文本。"
        case .toggleToTalk:
            "按一次开始录音，再按一次结束，适合长句或不方便一直按住时使用。"
        }
    }
}

enum HotkeyPreset: String, CaseIterable, Identifiable {
    case optionSpace
    case commandShiftSpace
    case fn

    var id: String { rawValue }

    var title: String {
        switch self {
        case .optionSpace:
            "Option + Space"
        case .commandShiftSpace:
            "Command + Shift + Space"
        case .fn:
            "Fn"
        }
    }

    var configuration: HotkeyConfiguration {
        switch self {
        case .optionSpace:
            HotkeyConfiguration(keyCode: 49, modifiers: [.option], displayName: "⌥ Space")
        case .commandShiftSpace:
            HotkeyConfiguration(keyCode: 49, modifiers: [.command, .shift], displayName: "⌘⇧ Space")
        case .fn:
            HotkeyConfiguration(keyCode: 63, modifiers: [], displayName: "Fn")
        }
    }
}

enum HotkeyValidationSeverity {
    case warning
    case error
}

struct HotkeyValidationIssue {
    let severity: HotkeyValidationSeverity
    let message: String
}

extension HotkeyConfiguration {
    private static let primaryModifierMask: NSEvent.ModifierFlags = [.command, .option, .control, .function]
    private static let supportedModifierMask: NSEvent.ModifierFlags = [.command, .option, .control, .shift, .function]

    static func make(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) -> HotkeyConfiguration {
        let normalizedModifiers = modifiers.intersection(supportedModifierMask)
        return HotkeyConfiguration(
            keyCode: keyCode,
            modifiers: normalizedModifiers,
            displayName: HotkeyFormatter.displayName(forKeyCode: keyCode, modifiers: normalizedModifiers)
        )
    }

    static func capture(from event: NSEvent) -> HotkeyConfiguration? {
        let modifiers = event.modifierFlags.intersection(supportedModifierMask)

        switch event.type {
        case .keyDown:
            return make(keyCode: event.keyCode, modifiers: modifiers)
        case .flagsChanged:
            guard event.keyCode == 63, modifiers.contains(.function) else { return nil }
            return make(keyCode: 63, modifiers: [])
        default:
            return nil
        }
    }

    var validationIssue: HotkeyValidationIssue? {
        if keyCode == 63, modifiers.isEmpty {
            return HotkeyValidationIssue(severity: .warning, message: "单独使用 Fn 在部分键盘工具或系统设置下可能不稳定；如果你发现偶发失效，建议换成带修饰键的组合。")
        }

        if let reservedMessage = reservedSystemConflictMessage {
            return HotkeyValidationIssue(severity: .error, message: reservedMessage)
        }

        if modifiers.isEmpty {
            return HotkeyValidationIssue(severity: .warning, message: "单键快捷键会直接截获这个按键，平时打字时也会被它抢走；如果你想少一点误触，建议加一个修饰键。")
        }

        if modifiers == [.command] || modifiers == [.control] || modifiers == [.option] {
            return HotkeyValidationIssue(severity: .warning, message: "这个组合在很多应用里都有快捷键，可能和别的软件冲突；如果发现按键无反应，换一个组合会更稳。")
        }

        return nil
    }

    private var reservedSystemConflictMessage: String? {
        switch (keyCode, modifiers) {
        case (49, [.command]):
            return "⌘ Space 通常被系统保留给 Spotlight，建议换一个组合。"
        case (49, [.control]):
            return "⌃ Space 常被系统保留给输入法切换，建议换一个组合。"
        case (48, [.command]):
            return "⌘ Tab 是系统应用切换快捷键，不能拿来做语音输入热键。"
        case (53, _):
            return "Escape 不能作为语音输入热键。"
        default:
            return nil
        }
    }
}

private enum HotkeyFormatter {
    private static let keyLabels: [UInt16: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X", 8: "C", 9: "V",
        11: "B", 12: "Q", 13: "W", 14: "E", 15: "R", 16: "Y", 17: "T", 18: "1", 19: "2", 20: "3",
        21: "4", 22: "6", 23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0", 30: "]",
        31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 37: "L", 38: "J", 39: "'", 40: "K", 41: ";",
        42: "\\", 43: ",", 44: "/", 45: "N", 46: "M", 47: ".", 49: "Space", 50: "`",
        36: "Return", 48: "Tab", 51: "Delete", 53: "Esc", 63: "Fn",
        122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6", 98: "F7", 100: "F8",
        101: "F9", 109: "F10", 103: "F11", 111: "F12", 123: "Left", 124: "Right", 125: "Down", 126: "Up"
    ]

    static func displayName(forKeyCode keyCode: UInt16, modifiers: NSEvent.ModifierFlags) -> String {
        let modifierPart = modifierDisplay(modifiers)
        let keyPart = keyLabels[keyCode] ?? "Key \(keyCode)"
        return modifierPart + keyPart
    }

    private static func modifierDisplay(_ modifiers: NSEvent.ModifierFlags) -> String {
        var parts: [String] = []
        if modifiers.contains(.control) { parts.append("⌃") }
        if modifiers.contains(.option) { parts.append("⌥") }
        if modifiers.contains(.shift) { parts.append("⇧") }
        if modifiers.contains(.command) { parts.append("⌘") }
        if modifiers.contains(.function) { parts.append("Fn") }
        return parts.joined()
    }
}
