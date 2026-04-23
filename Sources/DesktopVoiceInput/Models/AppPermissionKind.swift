import Foundation

enum AppPermissionKind: String, CaseIterable, Identifiable {
    case microphone
    case speechRecognition
    case accessibility
    case inputMonitoring

    var id: String { rawValue }

    var title: String {
        switch self {
        case .microphone:
            "麦克风"
        case .speechRecognition:
            "语音识别"
        case .accessibility:
            "辅助功能"
        case .inputMonitoring:
            "输入监控"
        }
    }

    var guidance: String {
        switch self {
        case .microphone:
            "用来采集你说话的声音。不授权就无法录音。"
        case .speechRecognition:
            "本地识别依赖它把语音转成文字。云端模式可作为兜底。"
        case .accessibility:
            "用来把识别结果写回当前输入框。不授权就只能看到预览，不能自动出字。"
        case .inputMonitoring:
            "用来监听全局按住说话快捷键。不授权时热键可能不生效。"
        }
    }

    var settingsURLString: String {
        switch self {
        case .microphone:
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone"
        case .speechRecognition:
            "x-apple.systempreferences:com.apple.preference.security?Privacy_SpeechRecognition"
        case .accessibility:
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        case .inputMonitoring:
            "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent"
        }
    }

    var canPromptInApp: Bool {
        switch self {
        case .microphone, .speechRecognition, .inputMonitoring:
            true
        case .accessibility:
            false
        }
    }
}
