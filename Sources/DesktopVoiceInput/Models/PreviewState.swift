import Combine
import Foundation

@MainActor
final class PreviewState: ObservableObject {
    @Published var isVisible = false
    @Published var title = "GuGuTalk"
    @Published var message = "按住或按一下快捷键开始说话"
    @Published var transcript = ""
    @Published var hintMessage: String?
    @Published var errorMessage: String?
    @Published var audioLevel: Float = 0
    @Published var isRecording = false
    @Published var isPostProcessing = false
    @Published var activeMode: RecognitionMode = .local

    var menuBarSymbolName: String {
        if errorMessage != nil {
            return "exclamationmark.triangle.fill"
        }

        return isRecording ? "waveform.badge.mic" : "mic.fill"
    }

    func resetToIdle() {
        title = "GuGuTalk"
        message = "按住或按一下快捷键开始说话"
        transcript = ""
        hintMessage = nil
        errorMessage = nil
        audioLevel = 0
        isRecording = false
        isPostProcessing = false
        activeMode = .local
    }
}
