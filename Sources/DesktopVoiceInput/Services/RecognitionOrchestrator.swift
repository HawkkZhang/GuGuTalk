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

    private let settings: AppSettings
    private let permissionCoordinator: PermissionCoordinator
    private let previewState: PreviewState
    private let audioCaptureEngine: AudioCaptureEngine
    private let providerFactory: ProviderFactory
    private let postProcessor: TranscriptPostProcessor
    private let smartPostProcessor: SmartPostProcessor
    private let textInsertionService: TextInsertionService

    private var activeProvider: SpeechProvider?
    private var consumeEventsTask: Task<Void, Never>?
    private var dismissTask: Task<Void, Never>?
    private var finalTranscript: String = ""
    private var isPendingStop = false
    private var isSessionActive = false

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
        guard !isSessionActive else { return }

        dismissTask?.cancel()
        dismissTask = nil

        previewState.resetToIdle()
        finalTranscript = ""
        lastErrorMessage = nil
        lastInsertionResult = nil
        isPendingStop = false

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

        do {
            let selection = try await startProviderChain(selections, config: config)
            previewState.activeMode = selection.mode
            previewState.message = "按住说话，松开后会插入最终文本"
            isSessionActive = true
            isSessionRunning = true

            try audioCaptureEngine.startCapture { [weak self] chunk in
                guard let self else { return }
                await MainActor.run {
                    self.previewState.audioLevel = chunk.audioLevel
                }

                do {
                    try await selection.provider.sendAudio(chunk)
                } catch {
                    await MainActor.run {
                        self.fail(message: "发送音频失败：\(error.localizedDescription)")
                    }
                }
            }

            if isPendingStop {
                await endCapture()
            }
        } catch {
            fail(message: error.localizedDescription)
        }
    }

    private var sessionTimeoutTask: Task<Void, Never>?

    func endCapture() async {
        guard let activeProvider else {
            isPendingStop = true
            return
        }

        guard isSessionActive else {
            isPendingStop = true
            return
        }

        isPendingStop = false
        previewState.isRecording = false
        previewState.message = "正在处理最后的音频"

        // 延迟停止音频捕获，确保最后的音频被处理
        try? await Task.sleep(for: .milliseconds(300))
        audioCaptureEngine.stopCapture()

        let hadTranscript = !finalTranscript.isEmpty || !previewState.transcript.isEmpty

        do {
            try await activeProvider.finishAudio()
        } catch {
            if hadTranscript {
                fail(message: "结束识别时出错：\(friendlyErrorMessage(error))")
            } else {
                dismissQuietly(message: "说话时间太短，没有识别到内容")
            }
            return
        }

        sessionTimeoutTask?.cancel()
        sessionTimeoutTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled, self.isSessionActive else { return }
            Self.logger.warning("Session timed out waiting for final result, force ending")
            let transcript = self.previewState.transcript
            if !transcript.isEmpty, self.finalTranscript.isEmpty {
                self.finalTranscript = self.smartPostProcessor.processRulesOnly(text: transcript)
                if !self.finalTranscript.isEmpty {
                    let result = self.textInsertionService.insert(text: self.finalTranscript)
                    self.lastInsertionResult = result
                }
            }
            self.forceEndSession()
        }
    }

    private func startProviderChain(_ selections: [ProviderSelection], config: RecognitionConfig) async throws -> ProviderSelection {
        var previousMode: RecognitionMode?
        var lastFailure: Error?

        for selection in selections {
            do {
                subscribe(to: selection.provider.events)
                try await selection.provider.startSession(config: config)

                if let previousMode {
                    previewState.message = "已自动切换到 \(selection.mode.title)：本地引擎不可用"
                    previewState.activeMode = selection.mode
                    let switchInfo = ProviderSwitchInfo(from: previousMode, to: selection.mode, reason: "上一引擎启动失败")
                    handleEvent(.providerSwitched(switchInfo))
                }

                activeProvider = selection.provider
                return selection
            } catch {
                Self.logger.error("Provider start failed. mode=\(selection.mode.title, privacy: .public) error=\(error.localizedDescription, privacy: .public)")
                previousMode = selection.mode
                lastFailure = error
            }
        }

        throw lastFailure ?? SessionFailureInfo(message: "所有识别引擎都不可用。")
    }

    private func subscribe(to stream: AsyncStream<TranscriptEvent>) {
        consumeEventsTask?.cancel()
        consumeEventsTask = Task { [weak self] in
            for await event in stream {
                await MainActor.run {
                    self?.handleEvent(event)
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
            if basicResult.isEmpty {
                dismissQuietly(message: "没有识别到有效内容")
                return
            }

            let frontmostApp = NSWorkspace.shared.frontmostApplication
            let targetApp = frontmostApp?.localizedName
            let targetBundleID = frontmostApp?.bundleIdentifier

            if settings.postProcessingEnabled, settings.activePostProcessingPrompt != nil, settings.llmProviderConfig.isConfigured {
                previewState.transcript = basicResult
                previewState.message = "正在处理文本"
                previewState.isPostProcessing = true

                Task { @MainActor in
                    do {
                        let processed = try await withThrowingTaskGroup(of: String.self) { group in
                            // LLM 处理任务
                            group.addTask {
                                await self.smartPostProcessor.process(
                                    text: basicResult, targetApp: targetApp, targetBundleID: targetBundleID
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

                        self.finalTranscript = processed.isEmpty ? basicResult : processed
                        self.previewState.transcript = self.finalTranscript
                        self.previewState.isPostProcessing = false
                        self.insertFinalText()

                        // LLM 完成后才 dismiss
                        if !self.isSessionActive {
                            self.scheduleDismiss(delay: 1.0)
                        }
                    } catch {
                        // 超时或失败，回退到基础结果
                        Self.logger.info("LLM post-processing timeout or failed, using basic result")
                        let processed = self.smartPostProcessor.processRulesOnly(text: basicResult)
                        self.finalTranscript = processed.isEmpty ? basicResult : processed
                        self.previewState.transcript = self.finalTranscript
                        self.previewState.isPostProcessing = false
                        self.previewState.hintMessage = "AI 优化超时，已插入原文"
                        self.insertFinalText()

                        if !self.isSessionActive {
                            self.scheduleDismiss(delay: 1.0)
                        }
                    }
                }
            } else {
                let processed = smartPostProcessor.processRulesOnly(text: basicResult)
                finalTranscript = processed.isEmpty ? basicResult : processed
                previewState.transcript = finalTranscript
                insertFinalText()
            }
        case .providerSwitched(let info):
            previewState.message = "已切换 \(info.from.title) -> \(info.to.title)"
        case .sessionFailed(let failure):
            let currentTranscript = previewState.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
            let hadContent = !finalTranscript.isEmpty || !currentTranscript.isEmpty

            if hadContent {
                if finalTranscript.isEmpty && !currentTranscript.isEmpty {
                    Self.logger.info("Session failed but have partial results, attempting to use them as final")
                    finalTranscript = smartPostProcessor.processRulesOnly(text: currentTranscript)
                    previewState.transcript = finalTranscript
                    insertFinalText()
                    previewState.hintMessage = "识别未完成，已插入部分结果"
                } else {
                    fail(message: friendlyErrorMessage(failure))
                }
            } else {
                dismissQuietly(message: "说话时间太短，没有识别到内容")
            }
        case .sessionEnded:
            finishSession()
        }
    }

    private func finishSession() {
        sessionTimeoutTask?.cancel()
        sessionTimeoutTask = nil
        consumeEventsTask?.cancel()
        consumeEventsTask = nil
        isSessionActive = false
        isSessionRunning = false
        activeProvider = nil
        previewState.isRecording = false

        // 如果正在 LLM 后处理，推迟 dismiss，等 LLM Task 完成后再调用
        if !previewState.isPostProcessing {
            scheduleDismiss(delay: previewState.errorMessage == nil ? 1.0 : 2.5)
        }
    }

    private func forceEndSession() {
        sessionTimeoutTask?.cancel()
        sessionTimeoutTask = nil
        consumeEventsTask?.cancel()
        consumeEventsTask = nil
        isSessionActive = false
        isSessionRunning = false
        activeProvider = nil
        previewState.isRecording = false

        scheduleDismiss(delay: 1.0)
    }

    private func insertFinalText() {
        previewState.message = "正在插入到当前输入位置"
        let result = textInsertionService.insert(text: finalTranscript)
        lastInsertionResult = result
        if result.succeeded {
            previewState.message = "已插入到当前应用"
        } else {
            previewState.errorMessage = result.failureReason
            lastErrorMessage = result.failureReason
            scheduleDismiss(delay: 3.0)
        }
    }

    private func fail(message: String) {
        sessionTimeoutTask?.cancel()
        sessionTimeoutTask = nil
        audioCaptureEngine.stopCapture()
        previewState.isVisible = true
        previewState.isRecording = false
        previewState.errorMessage = message
        previewState.title = "语音输入失败"
        previewState.message = ""
        lastErrorMessage = message
        isSessionActive = false
        isSessionRunning = false
        consumeEventsTask?.cancel()
        activeProvider = nil

        scheduleDismiss(delay: 2.5)
    }

    private func dismissQuietly(message: String) {
        previewState.isRecording = false
        previewState.hintMessage = message
        previewState.transcript = ""
        previewState.errorMessage = nil
        isSessionActive = false
        isSessionRunning = false
        consumeEventsTask?.cancel()
        consumeEventsTask = nil
        audioCaptureEngine.stopCapture()
        activeProvider = nil

        scheduleDismiss(delay: 1.2)
    }

    private func scheduleDismiss(delay: Double) {
        dismissTask?.cancel()
        dismissTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            self.previewState.isVisible = false
            self.previewState.resetToIdle()
        }
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
