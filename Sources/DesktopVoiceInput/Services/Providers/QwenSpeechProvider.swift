import Foundation

final class QwenSpeechProvider: NSObject, SpeechProvider, @unchecked Sendable {
    let mode: RecognitionMode = .qwen
    let events: AsyncStream<TranscriptEvent>

    private let continuation: AsyncStream<TranscriptEvent>.Continuation
    private var transport: RealtimeWebSocketTransport?
    private var revision = 0
    private var endpointingPolicy: EndpointingPolicy = .voiceActivityDetection
    private var accumulatedTranscript = ""
    private var latestTranscript = ""
    private var hasRequestedFinish = false
    private var hasEmittedFinalResult = false
    private var hasTerminatedSession = false

    override init() {
        var continuation: AsyncStream<TranscriptEvent>.Continuation?
        self.events = AsyncStream { streamContinuation in
            continuation = streamContinuation
        }
        self.continuation = continuation!
        super.init()
    }

    func startSession(config: RecognitionConfig) async throws {
        guard config.qwenCredentials.isConfigured else {
            throw SessionFailureInfo(message: "千问语音识别凭证未配置。")
        }

        guard let url = Self.makeRealtimeURL(endpoint: config.qwenCredentials.endpoint, model: config.qwenCredentials.model) else {
            throw SessionFailureInfo(message: "千问 WebSocket 地址无效。")
        }

        var request = URLRequest(url: url)
        request.addValue("Bearer \(config.qwenCredentials.apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("realtime=v1", forHTTPHeaderField: "OpenAI-Beta")
        self.revision = 0
        self.endpointingPolicy = config.endpointing
        self.accumulatedTranscript = ""
        self.latestTranscript = ""
        self.hasRequestedFinish = false
        self.hasEmittedFinalResult = false
        self.hasTerminatedSession = false
        self.transport = RealtimeWebSocketTransport(
            request: request,
            onMessage: { [weak self] message in
                guard let self else { return }

                switch message {
                case .text(let text):
                    self.handleMessage(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        self.handleMessage(text)
                    }
                }
            },
            onDisconnected: { [weak self] error in
                guard let self else { return }

                if self.hasRequestedFinish || self.hasEmittedFinalResult {
                    if !self.hasEmittedFinalResult {
                        let finalText = self.latestTranscript.isEmpty ? self.accumulatedTranscript : self.latestTranscript
                        if !finalText.isEmpty {
                            self.hasEmittedFinalResult = true
                            self.continuation.yield(.finalTextReady(text: finalText))
                        }
                    }

                    self.emitSessionEndedIfNeeded()
                    return
                }

                guard let error else {
                    self.emitSessionEndedIfNeeded()
                    return
                }

                self.continuation.yield(.sessionFailed(SessionFailureInfo(message: "千问连接中断：\(error.localizedDescription)")))
                self.emitSessionEndedIfNeeded()
            }
        )
        transport?.connect()

        continuation.yield(.sessionStarted(mode: mode))

        let sessionUpdate = QwenClientEvent.sessionUpdate(
            session: .init(
                language: Self.qwenLanguage(from: config.languageCode),
                inputAudioFormat: "pcm",
                sampleRate: Int(config.sampleRate),
                partialResultsEnabled: config.partialResultsEnabled,
                endpointingPolicy: config.endpointing
            )
        )

        try await transport?.send(text: sessionUpdate.jsonString)
    }

    func sendAudio(_ chunk: AudioChunk) async throws {
        let event = QwenClientEvent.appendAudio(audio: chunk.pcmData.base64EncodedString())
        try await transport?.send(text: event.jsonString)
    }

    func finishAudio() async throws {
        hasRequestedFinish = true

        if endpointingPolicy == .manual {
            try await transport?.send(text: QwenClientEvent.commit().jsonString)
        }

        try await transport?.send(text: QwenClientEvent.finish().jsonString)
    }

    func cancel() async {
        transport?.close()
        emitSessionEndedIfNeeded()
    }

    private func handleMessage(_ text: String) {
        guard let data = text.data(using: .utf8) else { return }

        do {
            let event = try JSONDecoder().decode(QwenServerEvent.self, from: data)
            switch event.type {
            case "conversation.item.input_audio_transcription.text":
                revision += 1
                let turnText = (event.stash ?? "") + (event.text ?? "")
                latestTranscript = accumulatedTranscript + turnText
                continuation.yield(.partialTextUpdated(text: latestTranscript, revision: revision))
            case "conversation.item.input_audio_transcription.completed":
                let turnResult = event.transcript ?? event.text ?? ""
                accumulatedTranscript += turnResult
                latestTranscript = accumulatedTranscript
                if hasRequestedFinish && !hasEmittedFinalResult {
                    hasEmittedFinalResult = true
                    continuation.yield(.finalTextReady(text: accumulatedTranscript))
                } else {
                    revision += 1
                    continuation.yield(.partialTextUpdated(text: accumulatedTranscript, revision: revision))
                }
            case "conversation.item.input_audio_transcription.failed":
                let message = event.error?.message ?? event.message ?? "识别失败"
                continuation.yield(.sessionFailed(SessionFailureInfo(message: "千问识别失败：\(message)")))
                emitSessionEndedIfNeeded()
            case "session.created":
                break
            case "session.finished":
                if hasRequestedFinish && !hasEmittedFinalResult {
                    let finalText = latestTranscript.isEmpty ? accumulatedTranscript : latestTranscript
                    if !finalText.isEmpty {
                        hasEmittedFinalResult = true
                        continuation.yield(.finalTextReady(text: finalText))
                    }
                }
                emitSessionEndedIfNeeded()
            case "error":
                let message = event.message ?? event.error?.message ?? "未知错误"
                continuation.yield(.sessionFailed(SessionFailureInfo(message: "千问识别失败：\(message)")))
                emitSessionEndedIfNeeded()
            default:
                break
            }
        } catch {
            continuation.yield(.sessionFailed(SessionFailureInfo(message: "千问响应解析失败：\(error.localizedDescription)")))
            emitSessionEndedIfNeeded()
        }
    }

    private func emitSessionEndedIfNeeded() {
        guard !hasTerminatedSession else { return }
        hasTerminatedSession = true
        continuation.yield(.sessionEnded)
    }

    private static func makeRealtimeURL(endpoint: String, model: String) -> URL? {
        guard var components = URLComponents(string: endpoint) else { return nil }

        var queryItems = components.queryItems ?? []
        if !queryItems.contains(where: { $0.name == "model" }) {
            queryItems.append(URLQueryItem(name: "model", value: model))
        }
        components.queryItems = queryItems
        return components.url
    }

    private static func qwenLanguage(from languageCode: String) -> String {
        switch languageCode.lowercased() {
        case "zh-cn", "zh":
            "zh"
        case "en-us", "en":
            "en"
        case "ja-jp", "ja":
            "ja"
        default:
            "zh"
        }
    }
}

private struct QwenClientEvent: Encodable {
    struct SessionPayload: Encodable {
        struct InputAudioTranscription: Encodable {
            let language: String
        }

        struct TurnDetection: Encodable {
            let type: String
            let threshold: Double
            let silenceDurationMs: Int
        }

        let modalities: [String]
        let inputAudioFormat: String
        let sampleRate: Int
        let inputAudioTranscription: InputAudioTranscription
        let turnDetection: TurnDetection?
    }

    let eventID: String
    let type: String
    let session: SessionPayload?
    let audio: String?

    enum CodingKeys: String, CodingKey {
        case eventID = "event_id"
        case type
        case session
        case audio
    }

    static func sessionUpdate(session: SessionDescriptor) -> QwenClientEvent {
        return QwenClientEvent(
            eventID: UUID().uuidString,
            type: "session.update",
            session: SessionPayload(
                modalities: ["text"],
                inputAudioFormat: session.inputAudioFormat,
                sampleRate: session.sampleRate,
                inputAudioTranscription: .init(language: session.language),
                turnDetection: session.endpointingPolicy == .voiceActivityDetection
                    ? .init(type: "server_vad", threshold: session.partialResultsEnabled ? 0.0 : 0.5, silenceDurationMs: 800)
                    : nil
            ),
            audio: nil
        )
    }

    static func appendAudio(audio: String) -> QwenClientEvent {
        QwenClientEvent(eventID: UUID().uuidString, type: "input_audio_buffer.append", session: nil, audio: audio)
    }

    static func commit() -> QwenClientEvent {
        QwenClientEvent(eventID: UUID().uuidString, type: "input_audio_buffer.commit", session: nil, audio: nil)
    }

    static func finish() -> QwenClientEvent {
        QwenClientEvent(eventID: UUID().uuidString, type: "session.finish", session: nil, audio: nil)
    }

    var jsonString: String {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let data = (try? encoder.encode(self)) ?? Data()
        return String(decoding: data, as: UTF8.self)
    }

    struct SessionDescriptor {
        let language: String
        let inputAudioFormat: String
        let sampleRate: Int
        let partialResultsEnabled: Bool
        let endpointingPolicy: EndpointingPolicy
    }
}

private struct QwenServerEvent: Decodable {
    struct ErrorPayload: Decodable {
        let message: String?
    }

    let type: String
    let text: String?
    let stash: String?
    let transcript: String?
    let message: String?
    let error: ErrorPayload?
}
