import Foundation
import Speech
import os

final class LocalSpeechProvider: NSObject, SpeechProvider, @unchecked Sendable {
    let mode: RecognitionMode = .local
    let events: AsyncStream<TranscriptEvent>

    private let continuation: AsyncStream<TranscriptEvent>.Continuation
    private var recognitionTask: SFSpeechRecognitionTask?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognizer: SFSpeechRecognizer?
    private var revision = 0
    private var committedTranscript = ""
    private var currentSegmentTranscript = ""
    private var lastNonEmptySegment = ""
    private var lastTranscriptLength = 0

    private static let logger = Logger(subsystem: "com.desktopvoiceinput", category: "LocalSpeech")

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
        self.committedTranscript = ""
        self.currentSegmentTranscript = ""
        self.lastNonEmptySegment = ""
        self.lastTranscriptLength = 0

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
            let currentLength = transcript.count

            // 段落切换判定：长度回落（哪怕回落到 0）或完全清空都意味着 Apple Speech
            // 认为上一段已经结束、新的段落开始。必须先把旧段落 commit，避免被覆盖丢失。
            let isSegmentReset = currentLength == 0
                || currentLength < Int(Double(self.lastTranscriptLength) * 0.6)
            if isSegmentReset {
                if !self.currentSegmentTranscript.isEmpty {
                    Self.logger.debug("Segment reset: committing [\(self.currentSegmentTranscript, privacy: .public)] (old length=\(self.lastTranscriptLength), new length=\(currentLength))")
                    self.committedTranscript += self.currentSegmentTranscript
                }
                self.currentSegmentTranscript = transcript
            } else {
                self.currentSegmentTranscript = transcript
            }

            if !self.currentSegmentTranscript.isEmpty {
                self.lastNonEmptySegment = self.currentSegmentTranscript
            }
            self.lastTranscriptLength = currentLength
            let fullTranscript = self.committedTranscript + self.currentSegmentTranscript

            Self.logger.debug("Local speech: isFinal=\(result.isFinal) current=[\(transcript, privacy: .public)] full=[\(fullTranscript, privacy: .public)]")

            if result.isFinal {
                self.cleanupRecognitionResources(cancelTask: false)
                // Final fallback：如果 final 回调时 current/committed 都已被清空，
                // 回退到我们自己记录的 lastNonEmptySegment + committed。
                var finalText = self.committedTranscript + self.currentSegmentTranscript
                if finalText.isEmpty, !self.lastNonEmptySegment.isEmpty {
                    Self.logger.debug("Final text empty, falling back to last non-empty segment: [\(self.lastNonEmptySegment, privacy: .public)]")
                    finalText = self.committedTranscript + self.lastNonEmptySegment
                }
                Self.logger.debug("Final result: [\(finalText, privacy: .public)]")
                self.continuation.yield(.finalTextReady(text: finalText))
                self.continuation.yield(.sessionEnded)
            } else {
                self.continuation.yield(.partialTextUpdated(text: fullTranscript, revision: self.revision))
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
