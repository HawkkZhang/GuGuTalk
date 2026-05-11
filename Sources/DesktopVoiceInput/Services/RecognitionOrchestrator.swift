import AppKit
import Combine
import Foundation
import os

@MainActor
final class RecognitionOrchestrator: ObservableObject {
    private static let logger = Logger(subsystem: "com.end.DesktopVoiceInput", category: "RecognitionOrchestrator")
    @Published private(set) var lastInsertionResult: InsertionResult?
    @Published private(set) var lastErrorMessage: String?
    @Published private(set) var isSessionRunning = false

    var hasActiveWork: Bool {
        isStartingSession ||
            isSessionActive ||
            isSessionRunning ||
            isFinishRequested ||
            startingProvider != nil ||
            activeProvider != nil ||
            previewState.isPostProcessing ||
            postProcessingTask != nil
    }

    private let settings: AppSettings
    private let permissionCoordinator: PermissionCoordinator
    private let previewState: PreviewState
    private let audioCaptureEngine: AudioCaptureEngine
    private let providerFactory: ProviderFactory
    private let postProcessor: TranscriptPostProcessor
    private let smartPostProcessor: SmartPostProcessor
    private let textInsertionService: TextInsertionService

    private var activeProvider: SpeechProvider?
    private var startingProvider: SpeechProvider?
    private var consumeEventsTask: Task<Void, Never>?
    private var dismissTask: Task<Void, Never>?
    private var postProcessingTask: Task<Void, Never>?
    private var finalTranscript: String = ""
    private var isPendingStop = false
    private var isStartingSession = false
    private var isSessionActive = false
    private var isFinishRequested = false
    private var sessionGeneration = 0

    init(
        settings: AppSettings,
        permissionCoordinator: PermissionCoordinator,
        previewState: PreviewState,
        audioCaptureEngine: AudioCaptureEngine,
        providerFactory: ProviderFactory,
        postProcessor: TranscriptPostProcessor,
        smartPostProcessor: SmartPostProcessor,
        textInsertionService: TextInsertionService
    ) {
        self.settings = settings
        self.permissionCoordinator = permissionCoordinator
        self.previewState = previewState
        self.audioCaptureEngine = audioCaptureEngine
        self.providerFactory = providerFactory
        self.postProcessor = postProcessor
        self.smartPostProcessor = smartPostProcessor
        self.textInsertionService = textInsertionService
    }

    func beginCapture() async {
        guard !isStartingSession, !isSessionActive else {
            Self.logger.info("beginCapture ignored because a session is already active")
            return
        }

        sessionGeneration += 1
        let generation = sessionGeneration
        sessionTimeoutTask?.cancel()
        sessionTimeoutTask = nil
        dismissTask?.cancel()
        dismissTask = nil

        previewState.resetToIdle()
        finalTranscript = ""
        lastErrorMessage = nil
        lastInsertionResult = nil
        isPendingStop = false
        isStartingSession = true
        isFinishRequested = false

        // 快速检查权限（不弹窗）
        await permissionCoordinator.refreshAll(promptForSystemDialogs: false)
        guard permissionCoordinator.allRequiredForCaptureReady() else {
            let missing = permissionCoordinator
                .missingPermissions(for: settings.preferredMode)
                .map(\.title)
                .joined(separator: "、")
            fail(message: "缺少必要权限：\(missing)。请先在权限引导里完成授权。")
            return
        }

        let config = settings.recognitionConfig
        let selections = providerFactory.resolveProviders()
        guard !selections.isEmpty else {
            fail(message: "没有可用的识别引擎，请先配置本地或云端 provider。")
            return
        }

        // 立即显示气泡
        previewState.isVisible = true
        previewState.title = "正在聆听"
        previewState.message = "正在启动识别引擎"
        previewState.isRecording = true
        Self.logger.info("Starting capture. generation=\(generation, privacy: .public) mode=\(config.mode.title, privacy: .public) sampleRate=\(config.sampleRate, privacy: .public)")

        do {
            let selection = try await startProviderChain(selections, config: config, generation: generation)
            guard sessionGeneration == generation else {
                Self.logger.info("Ignoring provider start because capture generation was superseded. generation=\(generation, privacy: .public) currentGeneration=\(self.sessionGeneration, privacy: .public)")
                await selection.provider.cancel()
                return
            }

            previewState.activeMode = selection.mode
            previewState.message = "按住说话，松开后会插入最终文本"
            isSessionActive = true
            isSessionRunning = true
            isStartingSession = false
            Self.logger.info("Provider ready. mode=\(selection.mode.title, privacy: .public)")

            try audioCaptureEngine.startCapture { [weak self] chunk in
                guard let self else { return }
                let shouldSend = await MainActor.run {
                    guard self.sessionGeneration == generation, self.isSessionActive, !self.isFinishRequested else {
                        return false
                    }
                    self.previewState.audioLevel = chunk.audioLevel
                    return true
                }
                guard shouldSend else { return }

                do {
                    try await selection.provider.sendAudio(chunk)
                } catch {
                    await MainActor.run {
                        Self.logger.error("sendAudio failed: \(error.localizedDescription, privacy: .public)")
                        self.fail(message: "发送音频失败：\(error.localizedDescription)")
                    }
                }
            }
            Self.logger.info("Audio capture started")

            if isPendingStop {
                Self.logger.info("Pending stop detected immediately after capture start")
                await endCapture()
            }
        } catch {
            if error is SupersededSessionError {
                Self.logger.info("beginCapture stopped because a newer capture superseded this one")
                return
            }
            Self.logger.error("beginCapture failed: \(error.localizedDescription, privacy: .public)")
            isStartingSession = false
            fail(message: error.localizedDescription)
        }
    }

    private var sessionTimeoutTask: Task<Void, Never>?

    func endCapture() async {
        guard let activeProvider else {
            if isStartingSession {
                isPendingStop = true
                Self.logger.info("endCapture requested before provider is ready; marking pending stop")
            } else {
                Self.logger.info("endCapture ignored because there is no active provider")
            }
            return
        }

        guard isSessionActive else {
            Self.logger.info("endCapture ignored because session is not active")
            return
        }

        guard !isFinishRequested else {
            Self.logger.info("endCapture ignored because finish has already been requested")
            return
        }

        isPendingStop = false
        isFinishRequested = true
        previewState.isRecording = false
        previewState.message = "正在处理最后的音频"
        Self.logger.info("Ending capture; stopping audio after tail buffer delay")

        // 延迟停止音频捕获，确保最后的音频被处理
        let finishingGeneration = sessionGeneration
        try? await Task.sleep(for: .milliseconds(300))
        guard isSessionActive, sessionGeneration == finishingGeneration else {
            Self.logger.info("Skipping finishAudio because session ended or changed during tail delay. finishingGeneration=\(finishingGeneration, privacy: .public) currentGeneration=\(self.sessionGeneration, privacy: .public)")
            return
        }
        stopAudioCapture(reason: "user requested endCapture")

        let hadTranscript = !finalTranscript.isEmpty || !previewState.transcript.isEmpty

        do {
            try await activeProvider.finishAudio()
            Self.logger.info("finishAudio sent to provider")
        } catch {
            Self.logger.error("finishAudio failed: \(error.localizedDescription, privacy: .public)")
            if hadTranscript {
                fail(message: "结束识别时出错：\(friendlyErrorMessage(error))")
            } else {
                dismissQuietly(message: "说话时间太短，没有识别到内容")
            }
            return
        }

        guard isSessionActive, sessionGeneration == finishingGeneration else {
            Self.logger.info("Skipping final-result timeout because session ended or changed during finishAudio. finishingGeneration=\(finishingGeneration, privacy: .public) currentGeneration=\(self.sessionGeneration, privacy: .public)")
            return
        }

        sessionTimeoutTask?.cancel()
        let timeoutGeneration = finishingGeneration
        sessionTimeoutTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled, self.isSessionActive else { return }
            guard self.sessionGeneration == timeoutGeneration else {
                Self.logger.info("Ignoring stale final-result timeout. timeoutGeneration=\(timeoutGeneration, privacy: .public) currentGeneration=\(self.sessionGeneration, privacy: .public)")
                return
            }
            Self.logger.warning("Session timed out waiting for final result, force ending")
            let transcript = self.previewState.transcript
            if !transcript.isEmpty, self.finalTranscript.isEmpty {
                self.finalTranscript = self.smartPostProcessor.processRulesOnly(text: transcript)
                if !self.finalTranscript.isEmpty {
                    Self.logger.warning("Inserting fallback transcript after final-result timeout: \(self.finalTranscript, privacy: .public)")
                    let result = self.textInsertionService.insert(text: self.finalTranscript)
                    self.lastInsertionResult = result
                }
            }
            self.forceEndSession()
        }
    }

    func cancelActiveWorkForRestart(reason: String) async {
        guard hasActiveWork else {
            Self.logger.info("Restart cleanup skipped because there is no active recognition work. reason=\(reason, privacy: .public)")
            dismissTask?.cancel()
            dismissTask = nil
            previewState.resetToIdle()
            return
        }

        Self.logger.warning("Cancelling active recognition work for user restart. reason=\(reason, privacy: .public)")
        sessionGeneration += 1
        sessionTimeoutTask?.cancel()
        sessionTimeoutTask = nil
        dismissTask?.cancel()
        dismissTask = nil
        postProcessingTask?.cancel()
        postProcessingTask = nil
        consumeEventsTask?.cancel()
        consumeEventsTask = nil

        let provider = activeProvider
        let providerStartingUp = startingProvider
        activeProvider = nil
        startingProvider = nil
        stopAudioCapture(reason: "user restart: \(reason)")

        finalTranscript = ""
        isStartingSession = false
        isPendingStop = false
        isFinishRequested = false
        isSessionActive = false
        isSessionRunning = false
        previewState.resetToIdle()

        await provider?.cancel()
        if let providerStartingUp {
            if let provider, providerStartingUp === provider {
                return
            }
            await providerStartingUp.cancel()
        }
    }

    private func startProviderChain(_ selections: [ProviderSelection], config: RecognitionConfig, generation: Int) async throws -> ProviderSelection {
        var previousMode: RecognitionMode?
        var lastFailure: Error?

        for selection in selections {
            guard sessionGeneration == generation else {
                throw SupersededSessionError()
            }

            do {
                subscribe(to: selection.provider.events, generation: generation)
                startingProvider = selection.provider
                try await selection.provider.startSession(config: config)
                if startingProvider === selection.provider {
                    startingProvider = nil
                }
                guard sessionGeneration == generation else {
                    await selection.provider.cancel()
                    throw SupersededSessionError()
                }

                if let previousMode {
                    previewState.message = "已自动切换到 \(selection.mode.title)：本地引擎不可用"
                    previewState.activeMode = selection.mode
                    let switchInfo = ProviderSwitchInfo(from: previousMode, to: selection.mode, reason: "上一引擎启动失败")
                    handleEvent(.providerSwitched(switchInfo))
                }

                activeProvider = selection.provider
                return selection
            } catch {
                if startingProvider === selection.provider {
                    startingProvider = nil
                }
                if error is SupersededSessionError {
                    throw error
                }
                guard sessionGeneration == generation else {
                    await selection.provider.cancel()
                    throw SupersededSessionError()
                }
                Self.logger.error("Provider start failed. mode=\(selection.mode.title, privacy: .public) error=\(error.localizedDescription, privacy: .public)")
                previousMode = selection.mode
                lastFailure = error
            }
        }

        throw lastFailure ?? SessionFailureInfo(message: "所有识别引擎都不可用。")
    }

    private func subscribe(to stream: AsyncStream<TranscriptEvent>, generation: Int) {
        consumeEventsTask?.cancel()
        consumeEventsTask = Task { [weak self] in
            for await event in stream {
                await MainActor.run {
                    guard let self else { return }
                    guard self.sessionGeneration == generation else {
                        Self.logger.info("Ignoring stale provider event. eventGeneration=\(generation, privacy: .public) currentGeneration=\(self.sessionGeneration, privacy: .public)")
                        return
                    }
                    self.handleEvent(event)
                }
            }
        }
    }

    private func handleEvent(_ event: TranscriptEvent) {
        switch event {
        case .sessionStarted(let mode):
            previewState.activeMode = mode
        case .audioLevelUpdated(let level):
            previewState.audioLevel = level
        case .partialTextUpdated(let text, _):
            previewState.transcript = text
        case .finalTextReady(let text):
            // 保底网：如果 provider 返回空 final 但 preview 气泡里有文字，用 preview 兜底
            var finalText = text
            if finalText.isEmpty {
                let previewText = previewState.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
                if !previewText.isEmpty {
                    Self.logger.info("Final text empty but preview has content, using preview as fallback: [\(previewText, privacy: .public)]")
                    finalText = previewText
                }
            }

            let basicResult = postProcessor.finalize(finalText)

            // 第二层保底：如果 finalize 后为空，再用 preview 原始内容兜底
            var finalResult = basicResult
            if finalResult.isEmpty {
                let previewText = previewState.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
                if !previewText.isEmpty {
                    Self.logger.warning("Post-processor returned empty, using raw preview as final fallback: [\(previewText, privacy: .public)]")
                    finalResult = previewText
                }
            }

            if finalResult.isEmpty {
                Self.logger.info("Final text is empty after post-processing; dismissing quietly")
                dismissQuietly(message: "没有识别到有效内容")
                return
            }

            Self.logger.info("Final text pipeline. providerFinal=\(finalText, privacy: .public) basic=\(basicResult, privacy: .public) finalBeforeSmart=\(finalResult, privacy: .public)")

            let frontmostApp = NSWorkspace.shared.frontmostApplication
            let targetApp = frontmostApp?.localizedName
            let targetBundleID = frontmostApp?.bundleIdentifier

            if settings.postProcessingEnabled, settings.activePostProcessingPrompt != nil, settings.llmProviderConfig.isConfigured {
                previewState.transcript = finalResult
                previewState.message = "正在处理文本"
                previewState.isPostProcessing = true

                // 捕获需要的值，避免 sending 参数的数据竞争
                let textToProcess = finalResult
                let app = targetApp
                let bundleID = targetBundleID

                let processingGeneration = sessionGeneration
                postProcessingTask?.cancel()
                postProcessingTask = Task { @MainActor in
                    do {
                        let processed = try await withThrowingTaskGroup(of: String.self) { group in
                            // LLM 处理任务
                            group.addTask {
                                await self.smartPostProcessor.process(
                                    text: textToProcess, targetApp: app, targetBundleID: bundleID
                                )
                            }

                            // 8 秒超时任务
                            group.addTask {
                                try await Task.sleep(for: .seconds(8))
                                throw CancellationError()
                            }

                            // 返回第一个完成的结果
                            if let result = try await group.next() {
                                group.cancelAll()
                                return result
                            }
                            throw CancellationError()
                        }

                        guard !Task.isCancelled, self.sessionGeneration == processingGeneration else {
                            Self.logger.info("Ignoring stale LLM post-processing result. processingGeneration=\(processingGeneration, privacy: .public) currentGeneration=\(self.sessionGeneration, privacy: .public)")
                            return
                        }

                        self.finalTranscript = processed.isEmpty ? textToProcess : processed
                        Self.logger.info("LLM post-processing completed. insertedText=\(self.finalTranscript, privacy: .public)")
                        self.previewState.isPostProcessing = false
                        self.previewState.transcript = ""
                        self.previewState.hintMessage = nil
                        self.postProcessingTask = nil
                        if self.insertFinalText() {
                            self.dismissNow()
                        }
                    } catch {
                        guard !Task.isCancelled, self.sessionGeneration == processingGeneration else {
                            Self.logger.info("Ignoring stale LLM post-processing failure. processingGeneration=\(processingGeneration, privacy: .public) currentGeneration=\(self.sessionGeneration, privacy: .public)")
                            return
                        }

                        // 超时或失败，回退到基础结果
                        Self.logger.info("LLM post-processing timeout or failed, using basic result")
                        let processed = self.smartPostProcessor.processRulesOnly(text: textToProcess)
                        self.finalTranscript = processed.isEmpty ? textToProcess : processed
                        self.previewState.isPostProcessing = false
                        self.previewState.transcript = ""
                        self.previewState.hintMessage = "AI 优化超时，已插入原文"
                        self.postProcessingTask = nil
                        if self.insertFinalText(), !self.isSessionActive {
                            self.scheduleDismiss(delay: 1.0)
                        }
                    }
                }
            } else {
                let processed = smartPostProcessor.processRulesOnly(text: finalResult)
                finalTranscript = processed.isEmpty ? finalResult : processed
                Self.logger.info("Final text ready for insertion. insertedText=\(self.finalTranscript, privacy: .public)")
                previewState.transcript = finalTranscript
                if insertFinalText() {
                    scheduleDismiss(delay: 0.8)
                }
            }
        case .providerSwitched(let info):
            previewState.message = "已切换 \(info.from.title) -> \(info.to.title)"
        case .sessionFailed(let failure):
            let currentTranscript = previewState.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
            let hadContent = !finalTranscript.isEmpty || !currentTranscript.isEmpty
            Self.logger.error("Provider session failed. message=\(failure.message, privacy: .public) hadContent=\(hadContent, privacy: .public) finalAlreadyProduced=\(!self.finalTranscript.isEmpty, privacy: .public) currentTranscript=\(currentTranscript, privacy: .public)")

            if hadContent {
                if !finalTranscript.isEmpty {
                    Self.logger.info("Ignoring provider failure after final transcript was already produced")
                    finishSession(reason: "provider failure after final transcript")
                } else if !currentTranscript.isEmpty {
                    Self.logger.info("Session failed but have partial results, attempting to use them as final")
                    stopAudioCapture(reason: "provider failure with partial transcript")
                    finalTranscript = smartPostProcessor.processRulesOnly(text: currentTranscript)
                    previewState.transcript = finalTranscript
                    insertFinalText()
                    previewState.hintMessage = "识别未完成，已插入部分结果"
                    finishSession(reason: "provider failure used partial transcript")
                } else {
                    fail(message: friendlyErrorMessage(failure))
                }
            } else {
                dismissQuietly(message: "说话时间太短，没有识别到内容")
            }
        case .sessionEnded:
            finishSession(reason: "provider emitted sessionEnded")
        }
    }

    private func finishSession(reason: String) {
        Self.logger.info("Finishing recognition session. reason=\(reason, privacy: .public)")
        sessionTimeoutTask?.cancel()
        sessionTimeoutTask = nil
        consumeEventsTask?.cancel()
        consumeEventsTask = nil
        stopAudioCapture(reason: "finishSession: \(reason)")
        isStartingSession = false
        isPendingStop = false
        isFinishRequested = false
        isSessionActive = false
        isSessionRunning = false
        activeProvider = nil
        startingProvider = nil
        previewState.isRecording = false

        // 如果正在 LLM 后处理，推迟 dismiss，等 LLM Task 完成后再调用
        if !previewState.isPostProcessing, postProcessingTask == nil {
            scheduleDismiss(delay: previewState.errorMessage == nil ? 1.0 : 2.5)
        }
    }

    private func forceEndSession() {
        Self.logger.warning("Force ending recognition session")
        sessionTimeoutTask?.cancel()
        sessionTimeoutTask = nil
        postProcessingTask?.cancel()
        postProcessingTask = nil
        consumeEventsTask?.cancel()
        consumeEventsTask = nil
        stopAudioCapture(reason: "forceEndSession")
        isStartingSession = false
        isPendingStop = false
        isFinishRequested = false
        isSessionActive = false
        isSessionRunning = false
        activeProvider = nil
        startingProvider = nil
        previewState.isRecording = false

        scheduleDismiss(delay: 1.0)
    }

    @discardableResult
    private func insertFinalText() -> Bool {
        previewState.message = "正在插入到当前输入位置"
        Self.logger.info("Inserting final text: \(self.finalTranscript, privacy: .public)")
        let result = textInsertionService.insert(text: finalTranscript)
        lastInsertionResult = result
        if result.succeeded {
            Self.logger.info("Insertion succeeded. method=\(result.method.rawValue, privacy: .public) target=\(result.targetAppName ?? "unknown", privacy: .public)")
            previewState.message = "已插入到当前应用"
            return true
        } else {
            Self.logger.error("Insertion failed. reason=\(result.failureReason ?? "unknown", privacy: .public)")
            previewState.errorMessage = result.failureReason
            lastErrorMessage = result.failureReason
            scheduleDismiss(delay: 3.0)
            return false
        }
    }

    private func fail(message: String) {
        Self.logger.error("Session failed: \(message, privacy: .public)")
        sessionTimeoutTask?.cancel()
        sessionTimeoutTask = nil
        postProcessingTask?.cancel()
        postProcessingTask = nil
        stopAudioCapture(reason: "fail: \(message)")
        previewState.isVisible = true
        previewState.isRecording = false
        previewState.errorMessage = message
        previewState.title = "语音输入失败"
        previewState.message = ""
        lastErrorMessage = message
        isStartingSession = false
        isPendingStop = false
        isFinishRequested = false
        isSessionActive = false
        isSessionRunning = false
        consumeEventsTask?.cancel()
        activeProvider = nil
        startingProvider = nil

        scheduleDismiss(delay: 2.5)
    }

    private func dismissQuietly(message: String) {
        Self.logger.info("Dismissing session quietly. message=\(message, privacy: .public)")
        sessionTimeoutTask?.cancel()
        sessionTimeoutTask = nil
        postProcessingTask?.cancel()
        postProcessingTask = nil
        previewState.isRecording = false
        previewState.hintMessage = message
        previewState.transcript = ""
        previewState.errorMessage = nil
        isStartingSession = false
        isPendingStop = false
        isFinishRequested = false
        isSessionActive = false
        isSessionRunning = false
        consumeEventsTask?.cancel()
        consumeEventsTask = nil
        stopAudioCapture(reason: "dismissQuietly: \(message)")
        activeProvider = nil
        startingProvider = nil

        scheduleDismiss(delay: 1.2)
    }

    private func stopAudioCapture(reason: String) {
        Self.logger.info("Stopping audio capture. reason=\(reason, privacy: .public)")
        audioCaptureEngine.stopCapture()
    }

    private func scheduleDismiss(delay: Double) {
        Self.logger.info("Scheduling preview dismiss. delay=\(delay, privacy: .public)")
        dismissTask?.cancel()
        dismissTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            Self.logger.info("Dismissing preview after scheduled delay")
            self.previewState.isVisible = false
            self.previewState.resetToIdle()
        }
    }

    private func dismissNow() {
        dismissTask?.cancel()
        dismissTask = nil
        previewState.isVisible = false
        previewState.resetToIdle()
    }

    private func friendlyErrorMessage(_ error: Error) -> String {
        let raw = error.localizedDescription.lowercased()
        if raw.contains("cancelled") || raw.contains("cancel") {
            return "识别被中断"
        }
        if raw.contains("timeout") || raw.contains("timed out") {
            return "连接超时，请检查网络"
        }
        if raw.contains("network") || raw.contains("internet") || raw.contains("offline") {
            return "网络不可用，请检查连接"
        }
        if raw.contains("auth") || raw.contains("401") || raw.contains("403") || raw.contains("credential") {
            return "认证失败，请检查服务配置"
        }
        return error.localizedDescription
    }
}

private struct SupersededSessionError: Error {}
