import Combine
import Foundation

@MainActor
final class PreviewState: ObservableObject {
    @Published var isVisible = false
    @Published var title = "桌面语音输入"
    @Published var message = "按住或按一下快捷键开始说话"
    @Published var transcript = ""
    @Published var errorMessage: String?
    @Published var audioLevel: Float = 0
    @Published var isRecording = false
    @Published var activeMode: RecognitionMode = .local

    var menuBarSymbolName: String {
        if errorMessage != nil {
            return "exclamationmark.triangle.fill"
        }

        return isRecording ? "waveform.badge.mic" : "mic.fill"
    }

    func resetToIdle() {
        title = "桌面语音输入"
        message = "按住或按一下快捷键开始说话"
        transcript = ""
        errorMessage = nil
        audioLevel = 0
        isRecording = false
        activeMode = .local
    }
}
