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
        static let llmProtocolType = "llmProtocolType"
        static let llmEndpoint = "llmEndpoint"
        static let llmAPIKey = "llmAPIKey"
        static let llmModel = "llmModel"
        static let postProcessingEnabled = "postProcessingEnabled"
        static let postProcessingPreset = "postProcessingPreset"
        static let punctuationMode = "punctuationMode"
        static let customLLMPrompt = "customLLMPrompt_"
        static let customPostProcessingModes = "customPostProcessingModes"
        static let selectedCustomModeName = "selectedCustomModeName"
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

    @Published var llmProtocolType: LLMProtocolType {
        didSet { defaults.set(llmProtocolType.rawValue, forKey: Keys.llmProtocolType) }
    }

    @Published var llmEndpoint: String {
        didSet { defaults.set(llmEndpoint, forKey: Keys.llmEndpoint) }
    }

    @Published var llmAPIKey: String {
        didSet { defaults.set(llmAPIKey, forKey: Keys.llmAPIKey) }
    }

    @Published var llmModel: String {
        didSet { defaults.set(llmModel, forKey: Keys.llmModel) }
    }

    @Published var postProcessingEnabled: Bool {
        didSet { defaults.set(postProcessingEnabled, forKey: Keys.postProcessingEnabled) }
    }

    @Published var postProcessingPreset: PostProcessingPreset? {
        didSet { defaults.set(postProcessingPreset?.rawValue ?? "", forKey: Keys.postProcessingPreset) }
    }

    @Published var punctuationMode: PunctuationMode {
        didSet { defaults.set(punctuationMode.rawValue, forKey: Keys.punctuationMode) }
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
            // 默认：Fn 键
            self.holdToTalkHotkey = HotkeyConfiguration.make(keyCode: 63, modifiers: [])
        }
        self.holdToTalkEnabled = defaults.object(forKey: Keys.holdToTalkEnabled) == nil
            ? true
            : defaults.bool(forKey: Keys.holdToTalkEnabled)
        if defaults.object(forKey: Keys.toggleToTalkHotkeyKeyCode) != nil {
            let keyCode = UInt16(defaults.integer(forKey: Keys.toggleToTalkHotkeyKeyCode))
            let modifiers = NSEvent.ModifierFlags(rawValue: UInt(defaults.integer(forKey: Keys.toggleToTalkHotkeyModifiers)))
            self.toggleToTalkHotkey = HotkeyConfiguration.make(keyCode: keyCode, modifiers: modifiers)
        } else {
            // 默认：⌥Space
            self.toggleToTalkHotkey = HotkeyConfiguration.make(keyCode: 49, modifiers: [.option])
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
        self.llmProtocolType = LLMProtocolType(rawValue: defaults.string(forKey: Keys.llmProtocolType) ?? "") ?? .openAICompatible
        self.llmEndpoint = defaults.string(forKey: Keys.llmEndpoint) ?? ""
        self.llmAPIKey = defaults.string(forKey: Keys.llmAPIKey) ?? ""
        self.llmModel = defaults.string(forKey: Keys.llmModel) ?? ""
        self.postProcessingEnabled = defaults.bool(forKey: Keys.postProcessingEnabled)
        let presetRaw = defaults.string(forKey: Keys.postProcessingPreset) ?? ""
        self.postProcessingPreset = presetRaw.isEmpty ? nil : PostProcessingPreset(rawValue: presetRaw)
        self.punctuationMode = PunctuationMode(rawValue: defaults.string(forKey: Keys.punctuationMode) ?? "") ?? .keep
        let customModeName = defaults.string(forKey: Keys.selectedCustomModeName) ?? ""
        self.selectedCustomModeName = customModeName.isEmpty ? nil : customModeName
    }

    var llmProviderConfig: LLMProviderConfig {
        LLMProviderConfig(
            protocolType: llmProtocolType,
            endpoint: llmEndpoint.trimmingCharacters(in: .whitespacesAndNewlines),
            apiKey: llmAPIKey.trimmingCharacters(in: .whitespacesAndNewlines),
            model: llmModel.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    func customPrompt(for preset: PostProcessingPreset) -> String {
        defaults.string(forKey: Keys.customLLMPrompt + preset.rawValue) ?? ""
    }

    func setCustomPrompt(_ prompt: String, for preset: PostProcessingPreset) {
        defaults.set(prompt, forKey: Keys.customLLMPrompt + preset.rawValue)
        objectWillChange.send()
    }

    func effectivePrompt(for preset: PostProcessingPreset) -> String {
        let custom = customPrompt(for: preset)
        return custom.isEmpty ? preset.defaultPrompt : custom
    }

    // MARK: - Custom Post Processing Modes

    @Published var selectedCustomModeName: String? {
        didSet { defaults.set(selectedCustomModeName ?? "", forKey: Keys.selectedCustomModeName) }
    }

    var customModes: [CustomPostProcessingMode] {
        get {
            guard let data = defaults.data(forKey: Keys.customPostProcessingModes),
                  let decoded = try? JSONDecoder().decode([CustomPostProcessingMode].self, from: data) else {
                return []
            }
            return decoded
        }
        set {
            guard let data = try? JSONEncoder().encode(newValue) else { return }
            defaults.set(data, forKey: Keys.customPostProcessingModes)
            objectWillChange.send()
        }
    }

    func addCustomMode(name: String, prompt: String) {
        var modes = customModes
        modes.append(CustomPostProcessingMode(name: name, prompt: prompt))
        customModes = modes
    }

    func removeCustomMode(name: String) {
        var modes = customModes
        modes.removeAll { $0.name == name }
        customModes = modes
        if selectedCustomModeName == name {
            selectedCustomModeName = nil
        }
    }

    func updateCustomMode(name: String, prompt: String) {
        var modes = customModes
        if let index = modes.firstIndex(where: { $0.name == name }) {
            modes[index].prompt = prompt
            customModes = modes
        }
    }

    /// 当前生效的 LLM prompt（预设或自定义）
    var activePostProcessingPrompt: String? {
        if let customName = selectedCustomModeName,
           let mode = customModes.first(where: { $0.name == customName }) {
            return mode.prompt
        }
        if let preset = postProcessingPreset {
            return effectivePrompt(for: preset)
        }
        return nil
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
            // 计算当前有多少个修饰键被按下
            let activeModifiers = [
                modifiers.contains(.control),
                modifiers.contains(.option),
                modifiers.contains(.command),
                modifiers.contains(.shift),
                modifiers.contains(.function)
            ].filter { $0 }.count

            // 如果有多个修饰键，捕获修饰键组合
            if activeModifiers > 1 {
                // 使用当前按下的修饰键的 keyCode，其他修饰键作为 modifiers
                // 例如：Control + Option → keyCode = Option 的 keyCode, modifiers = [.control]
                var otherModifiers = modifiers

                // Fn 键
                if event.keyCode == 63, modifiers.contains(.function) {
                    otherModifiers.remove(.function)
                    return make(keyCode: 63, modifiers: otherModifiers)
                }

                // Control 键
                if (event.keyCode == 59 || event.keyCode == 62), modifiers.contains(.control) {
                    otherModifiers.remove(.control)
                    return make(keyCode: event.keyCode, modifiers: otherModifiers)
                }

                // Option 键
                if (event.keyCode == 58 || event.keyCode == 61), modifiers.contains(.option) {
                    otherModifiers.remove(.option)
                    return make(keyCode: event.keyCode, modifiers: otherModifiers)
                }

                // Command 键
                if (event.keyCode == 55 || event.keyCode == 54), modifiers.contains(.command) {
                    otherModifiers.remove(.command)
                    return make(keyCode: event.keyCode, modifiers: otherModifiers)
                }

                // Shift 键
                if (event.keyCode == 56 || event.keyCode == 60), modifiers.contains(.shift) {
                    otherModifiers.remove(.shift)
                    return make(keyCode: event.keyCode, modifiers: otherModifiers)
                }
            }

            // 单个修饰键作为单键
            // Fn 键
            if event.keyCode == 63, modifiers.contains(.function) {
                return make(keyCode: 63, modifiers: [])
            }

            // Control 键（左右）
            if (event.keyCode == 59 || event.keyCode == 62), modifiers.contains(.control) {
                return make(keyCode: event.keyCode, modifiers: [])
            }

            // Option 键（左右）
            if (event.keyCode == 58 || event.keyCode == 61), modifiers.contains(.option) {
                return make(keyCode: event.keyCode, modifiers: [])
            }

            // Command 键（左右）
            if (event.keyCode == 55 || event.keyCode == 54), modifiers.contains(.command) {
                return make(keyCode: event.keyCode, modifiers: [])
            }

            // Shift 键（左右）
            if (event.keyCode == 56 || event.keyCode == 60), modifiers.contains(.shift) {
                return make(keyCode: event.keyCode, modifiers: [])
            }

            return nil
        default:
            return nil
        }
    }

    var validationIssue: HotkeyValidationIssue? {
        // 允许的单键：修饰键 + 功能键 + Escape
        let modifierKeys: Set<UInt16> = [
            63,      // Fn
            59, 62,  // Control (左右)
            58, 61,  // Option (左右)
            55, 54,  // Command (左右)
            56, 60   // Shift (左右)
        ]

        let functionKeys: Set<UInt16> = [
            122, 120, 99, 118, 96, 97, 98, 100, 101, 109, 103, 111  // F1-F12
        ]

        let specialKeys: Set<UInt16> = [
            53  // Escape
        ]

        let allowedSingleKeys = modifierKeys.union(functionKeys).union(specialKeys)

        if modifiers.isEmpty && !allowedSingleKeys.contains(keyCode) {
            // 禁止的单键，返回 error（不显示文本，只用动效）
            return HotkeyValidationIssue(severity: .error, message: "")
        }

        return nil
    }

    var keyComponents: [String] {
        var components: [String] = []
        if modifiers.contains(.control) { components.append("⌃") }
        if modifiers.contains(.option) { components.append("⌥") }
        if modifiers.contains(.shift) { components.append("⇧") }
        if modifiers.contains(.command) { components.append("⌘") }
        if modifiers.contains(.function) { components.append("fn") }

        let keyName = HotkeyFormatter.displayName(forKeyCode: keyCode, modifiers: [])
        components.append(keyName)

        return components.isEmpty ? ["未设置"] : components
    }

    private var reservedSystemConflictMessage: String? {
        // 移除所有限制，让用户自己测试
        return nil
    }

    func conflictInfo(comparing other: HotkeyConfiguration?) -> HotkeyConflictInfo {
        // 只检查内部冲突
        if let other, self.keyCode == other.keyCode, self.modifiers == other.modifiers {
            return HotkeyConflictInfo(
                severity: .error,
                title: "快捷键冲突",
                details: ["长按说话和切换说话不能使用相同的快捷键"]
            )
        }

        // 移除单键警告，用户既然选择了就应该知道后果
        return HotkeyConflictInfo(severity: .none, title: nil, details: [])
    }

    private func checkCommonAppConflicts() -> [String] {
        // 不再猜测冲突
        return []
    }
}

struct HotkeyConflictInfo {
    enum Severity {
        case none
        case warning
        case error
    }

    let severity: Severity
    let title: String?
    let details: [String]
}

enum HotkeyFormatter {
    private static let keyLabels: [UInt16: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X", 8: "C", 9: "V",
        11: "B", 12: "Q", 13: "W", 14: "E", 15: "R", 16: "Y", 17: "T", 18: "1", 19: "2", 20: "3",
        21: "4", 22: "6", 23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0", 30: "]",
        31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 37: "L", 38: "J", 39: "'", 40: "K", 41: ";",
        42: "\\", 43: ",", 44: "/", 45: "N", 46: "M", 47: ".", 49: "Space", 50: "`",
        36: "Return", 48: "Tab", 51: "Delete", 53: "Esc", 63: "Fn",
        122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6", 98: "F7", 100: "F8",
        101: "F9", 109: "F10", 103: "F11", 111: "F12", 123: "Left", 124: "Right", 125: "Down", 126: "Up",
        // 修饰键
        59: "⌃", 62: "⌃",  // Control (左右)
        58: "⌥", 61: "⌥",  // Option (左右)
        55: "⌘", 54: "⌘",  // Command (左右)
        56: "⇧", 60: "⇧"   // Shift (左右)
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
