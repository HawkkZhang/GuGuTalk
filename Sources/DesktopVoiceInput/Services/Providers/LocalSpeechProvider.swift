import Foundation
import Speech

final class LocalSpeechProvider: NSObject, SpeechProvider, @unchecked Sendable {
    let mode: RecognitionMode = .local
    let events: AsyncStream<TranscriptEvent>

    private let continuation: AsyncStream<TranscriptEvent>.Continuation
    private var recognitionTask: SFSpeechRecognitionTask?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognizer: SFSpeechRecognizer?
    private var revision = 0

    override init() {
        var continuation: AsyncStream<TranscriptEvent>.Continuation?
        self.events = AsyncStream { streamContinuation in
            continuation = streamContinuation
        }
        self.continuation = continuation!
        super.init()
    }

    func startSession(config: RecognitionConfig) async throws {
        guard SFSpeechRecognizer.authorizationStatus() == .authorized else {
            throw SessionFailureInfo(message: "本地语音识别权限未授权。")
        }

        let locale = Locale(identifier: config.languageCode.replacingOccurrences(of: "-", with: "_"))
        guard let recognizer = SFSpeechRecognizer(locale: locale) else {
            throw SessionFailureInfo(message: "本地语音识别器不可用。")
        }

        guard recognizer.isAvailable else {
            throw SessionFailureInfo(message: "本地语音识别当前不可用。")
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = true
        request.taskHint = .dictation

        self.recognizer = recognizer
        self.recognitionRequest = request
        self.revision = 0

        continuation.yield(.sessionStarted(mode: mode))

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }

            if let error {
                self.cleanupRecognitionResources(cancelTask: false)
                self.continuation.yield(.sessionFailed(SessionFailureInfo(message: error.localizedDescription)))
                self.continuation.yield(.sessionEnded)
                return
            }

            guard let result else { return }

            self.revision += 1
            let transcript = result.bestTranscription.formattedString

            if result.isFinal {
                self.cleanupRecognitionResources(cancelTask: false)
                self.continuation.yield(.finalTextReady(text: transcript))
                self.continuation.yield(.sessionEnded)
            } else {
                self.continuation.yield(.partialTextUpdated(text: transcript, revision: self.revision))
            }
        }
    }

    func sendAudio(_ chunk: AudioChunk) async throws {
        recognitionRequest?.append(chunk.nativeBuffer)
    }

    func finishAudio() async throws {
        recognitionRequest?.endAudio()
    }

    func cancel() async {
        cleanupRecognitionResources(cancelTask: true)
        continuation.yield(.sessionEnded)
    }

    private func cleanupRecognitionResources(cancelTask: Bool) {
        if cancelTask {
            recognitionTask?.cancel()
        }

        recognitionTask = nil
        recognitionRequest = nil
        recognizer = nil
    }
}
