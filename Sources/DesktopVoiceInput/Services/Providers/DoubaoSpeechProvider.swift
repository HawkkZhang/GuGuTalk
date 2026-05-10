import Foundation
import os
import zlib

final class DoubaoSpeechProvider: NSObject, SpeechProvider, @unchecked Sendable {
    let mode: RecognitionMode = .doubao
    let events: AsyncStream<TranscriptEvent>

    private static let logger = Logger(subsystem: "com.end.DesktopVoiceInput", category: "DoubaoSpeechProvider")

    private let continuation: AsyncStream<TranscriptEvent>.Continuation
    private var transport: RealtimeWebSocketTransport?
    private var revision = 0
    private var hasTerminatedSession = false
    private var hasEmittedFinalResult = false
    private var latestTranscript = ""
    private var hasRequestedFinish = false

    override init() {
        var continuation: AsyncStream<TranscriptEvent>.Continuation?
        self.events = AsyncStream { streamContinuation in
            continuation = streamContinuation
        }
        self.continuation = continuation!
        super.init()
    }

    func startSession(config: RecognitionConfig) async throws {
        guard config.doubaoCredentials.isConfigured else {
            throw SessionFailureInfo(message: "豆包语音识别凭证未配置。")
        }

        guard let url = URL(string: config.doubaoCredentials.endpoint) else {
            throw SessionFailureInfo(message: "豆包 WebSocket 地址无效。")
        }

        let connectID = UUID().uuidString
        var request = URLRequest(url: url)
        request.addValue(config.doubaoCredentials.appID, forHTTPHeaderField: "X-Api-App-Key")
        request.addValue(config.doubaoCredentials.accessKey, forHTTPHeaderField: "X-Api-Access-Key")
        request.addValue(config.doubaoCredentials.resourceID, forHTTPHeaderField: "X-Api-Resource-Id")
        request.addValue(connectID, forHTTPHeaderField: "X-Api-Connect-Id")
        self.revision = 0
        self.hasTerminatedSession = false
        self.hasEmittedFinalResult = false
        self.latestTranscript = ""
        self.hasRequestedFinish = false
        self.transport = RealtimeWebSocketTransport(
            request: request,
            onMessage: { [weak self] message in
                guard let self else { return }

                switch message {
                case .data(let data):
                    self.handleIncomingData(data)
                case .text(let string):
                    self.handleIncomingText(string)
                }
            },
            onDisconnected: { [weak self] error in
                guard let self else { return }
                guard !self.hasTerminatedSession else { return }

                if self.hasRequestedFinish, !self.hasEmittedFinalResult {
                    let finalText = self.latestTranscript
                    if !finalText.isEmpty {
                        Self.logger.info("Emitting fallback final transcript on disconnect: \(finalText, privacy: .public)")
                        self.hasEmittedFinalResult = true
                        self.continuation.yield(.finalTextReady(text: finalText))
                    }
                }

                if self.hasRequestedFinish || self.hasEmittedFinalResult {
                    self.emitSessionEndedIfNeeded()
                    return
                }

                guard let error else {
                    self.emitSessionEndedIfNeeded()
                    return
                }

                let message = error.localizedDescription
                if message.localizedCaseInsensitiveContains("socket is not connected") {
                    Self.logger.debug("Socket closed after termination or remote close: \(message, privacy: .public)")
                    self.emitSessionEndedIfNeeded()
                    return
                }

                Self.logger.error("Socket disconnected unexpectedly: \(message, privacy: .public)")
                self.continuation.yield(.sessionFailed(SessionFailureInfo(message: "豆包连接中断：\(message)")))
                self.emitSessionEndedIfNeeded()
            }
        )
        transport?.connect()
        Self.logger.info("Starting Doubao session. endpoint=\(config.doubaoCredentials.endpoint, privacy: .public) resource=\(config.doubaoCredentials.resourceID, privacy: .public)")

        continuation.yield(.sessionStarted(mode: mode))

        let payload = DoubaoFullClientRequest(
            user: .init(
                uid: Host.current().localizedName ?? UUID().uuidString,
                did: Host.current().localizedName ?? "macOS",
                platform: "macOS",
                sdkVersion: "GuGuTalk/1.0",
                appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
            ),
            audio: .init(format: "pcm", codec: "raw", rate: Int(config.sampleRate), bits: 16, channel: 1, language: nil),
            request: .init(
                modelName: "bigmodel",
                enableNonstream: true,
                showUtterances: true,
                resultType: "full",
                enableITN: true,
                enableDDC: false,
                enablePunc: true,
                showSpeechRate: false,
                showVolume: false,
                enableLID: false,
                enableEmotionDetection: false,
                hotWordList: nil
            )
        )

        let initialFrame = try DoubaoFrameBuilder.buildJSONRequestFrame(payload)
        try await transport?.send(data: initialFrame)
        Self.logger.debug("Sent Doubao initial request frame")
    }

    func sendAudio(_ chunk: AudioChunk) async throws {
        let frame = try DoubaoFrameBuilder.buildAudioFrame(chunk: chunk.pcmData, isLastFrame: false)
        try await transport?.send(data: frame)
    }

    func finishAudio() async throws {
        hasRequestedFinish = true
        let frame = try DoubaoFrameBuilder.buildAudioFrame(chunk: Data(), isLastFrame: true)
        try await transport?.send(data: frame)
        Self.logger.debug("Sent Doubao finish audio frame")

        // 等待最后的结果到达，避免时序问题
        try? await Task.sleep(for: .milliseconds(200))
    }

    func cancel() async {
        transport?.close()
        emitSessionEndedIfNeeded()
    }

    private func handleIncomingData(_ data: Data) {
        if data.isLikelyJSONText {
            handleIncomingJSONPayload(data, source: "文本数据")
            return
        }

        do {
            try handleFrame(data)
        } catch {
            continuation.yield(.sessionFailed(SessionFailureInfo(message: "豆包响应解析失败：\(error.localizedDescription)")))
            continuation.yield(.sessionEnded)
        }
    }

    private func handleIncomingText(_ text: String) {
        handleIncomingJSONPayload(Data(text.utf8), source: "文本消息")
    }

    private func handleIncomingJSONPayload(_ data: Data, source: String) {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            let preview = String(data: data.prefix(160), encoding: .utf8) ?? data.prefix(32).hexPreview
            continuation.yield(.sessionFailed(SessionFailureInfo(message: "豆包返回了无法解析的\(source)：\(preview)")))
            continuation.yield(.sessionEnded)
            return
        }

        let code = json["code"] as? Int ?? json["status_code"] as? Int ?? -1
        let message = (json["message"] as? String) ?? (json["error"] as? String) ?? (json["msg"] as? String)
        if let message {
            if hasRequestedFinish, !hasEmittedFinalResult, !latestTranscript.isEmpty {
                Self.logger.info("豆包返回错误但有部分结果，使用部分结果作为最终结果: \(self.latestTranscript, privacy: .public)")
                hasEmittedFinalResult = true
                continuation.yield(.finalTextReady(text: latestTranscript))
                continuation.yield(.sessionEnded)
                return
            }
            continuation.yield(.sessionFailed(SessionFailureInfo(message: "豆包返回消息[\(code)]：\(message)")))
            continuation.yield(.sessionEnded)
            return
        }

        if let transcript = DoubaoTranscriptPayload(resultValue: json["result"]), transcript.hasText {
            latestTranscript = transcript.canonicalText
            revision += 1
            logTranscriptSnapshot(transcript, stage: "json", isTerminal: false)
            Self.logger.debug("Received JSON transcript. utterances=\(transcript.utterances.count, privacy: .public) definite=\(transcript.definiteCount, privacy: .public) finishRequested=\(self.hasRequestedFinish, privacy: .public) text=\(self.latestTranscript, privacy: .public)")
            continuation.yield(.partialTextUpdated(text: latestTranscript, revision: revision))
            return
        }

        let preview = String(data: data.prefix(160), encoding: .utf8) ?? data.prefix(32).hexPreview
        continuation.yield(.sessionFailed(SessionFailureInfo(message: "豆包返回了未识别的 JSON：\(preview)")))
        continuation.yield(.sessionEnded)
    }

    private func handleFrame(_ data: Data) throws {
        let response = try DoubaoFrameParser.parse(data)

        if let errorMessage = response.errorMessage {
            continuation.yield(.sessionFailed(SessionFailureInfo(message: "豆包识别失败：\(errorMessage)")))
            emitSessionEndedIfNeeded()
            return
        }

        if let errorMessage = response.transportError {
            continuation.yield(.sessionFailed(SessionFailureInfo(message: "豆包协议错误：\(errorMessage)")))
            emitSessionEndedIfNeeded()
            return
        }

        guard let transcript = response.transcript, transcript.hasText else {
            if response.isTerminal, hasRequestedFinish, !hasEmittedFinalResult {
                hasEmittedFinalResult = true
                Self.logger.info("Received terminal frame without transcript; emitting latest transcript as final: \(self.latestTranscript, privacy: .public)")
                continuation.yield(.finalTextReady(text: latestTranscript))
                emitSessionEndedIfNeeded()
            }
            return
        }

        latestTranscript = transcript.canonicalText
        revision += 1
        logTranscriptSnapshot(transcript, stage: response.isTerminal ? "terminal" : "partial", isTerminal: response.isTerminal)

        if response.isTerminal {
            Self.logger.debug("Received terminal transcript. utterances=\(transcript.utterances.count, privacy: .public) definite=\(transcript.definiteCount, privacy: .public) finishRequested=\(self.hasRequestedFinish, privacy: .public) text=\(self.latestTranscript, privacy: .public)")
            if hasRequestedFinish {
                hasEmittedFinalResult = true
                Self.logger.info("Doubao final emitted. text=\(self.latestTranscript, privacy: .public)")
                continuation.yield(.finalTextReady(text: latestTranscript))
                emitSessionEndedIfNeeded()
            } else {
                continuation.yield(.partialTextUpdated(text: latestTranscript, revision: revision))
            }
        } else {
            Self.logger.debug("Received partial transcript. utterances=\(transcript.utterances.count, privacy: .public) definite=\(transcript.definiteCount, privacy: .public) text=\(self.latestTranscript, privacy: .public)")
            continuation.yield(.partialTextUpdated(text: latestTranscript, revision: revision))
        }
    }

    private func logTranscriptSnapshot(_ transcript: DoubaoTranscriptPayload, stage: String, isTerminal: Bool) {
        let rawText = transcript.rawCanonicalText
        let normalizedText = transcript.canonicalText
        let changedByNormalizer = rawText != normalizedText
        let rawForLog = rawText.escapedForDiagnosticLog
        let normalizedForLog = normalizedText.escapedForDiagnosticLog

        if isTerminal || hasRequestedFinish || changedByNormalizer {
            Self.logger.info(
                "Doubao transcript snapshot. stage=\(stage, privacy: .public) terminal=\(isTerminal, privacy: .public) finishRequested=\(self.hasRequestedFinish, privacy: .public) changedByNormalizer=\(changedByNormalizer, privacy: .public) raw=\"\(rawForLog, privacy: .public)\" normalized=\"\(normalizedForLog, privacy: .public)\" utterances=\(transcript.utterances.count, privacy: .public) definite=\(transcript.definiteCount, privacy: .public)"
            )
        } else {
            Self.logger.debug(
                "Doubao transcript snapshot. stage=\(stage, privacy: .public) terminal=\(isTerminal, privacy: .public) finishRequested=\(self.hasRequestedFinish, privacy: .public) changedByNormalizer=\(changedByNormalizer, privacy: .public) raw=\"\(rawForLog, privacy: .public)\" normalized=\"\(normalizedForLog, privacy: .public)\" utterances=\(transcript.utterances.count, privacy: .public) definite=\(transcript.definiteCount, privacy: .public)"
            )
        }
    }

    private func emitSessionEndedIfNeeded() {
        guard !hasTerminatedSession else { return }
        hasTerminatedSession = true
        continuation.yield(.sessionEnded)
    }
}

private enum DoubaoFrameBuilder {
    static func buildJSONRequestFrame(_ request: DoubaoFullClientRequest) throws -> Data {
        let payload = try JSONEncoder().encode(request)
        let compressedPayload = try payload.gzipCompressed()
        return try buildFrame(
            messageType: 0b0001,
            messageFlags: 0b0000,
            serializationMethod: 0b0001,
            compression: 0b0001,
            payload: compressedPayload
        )
    }

    static func buildAudioFrame(chunk: Data, isLastFrame: Bool) throws -> Data {
        let compressedPayload = try chunk.gzipCompressed()
        return try buildFrame(
            messageType: 0b0010,
            messageFlags: isLastFrame ? 0b0010 : 0b0000,
            serializationMethod: 0b0000,
            compression: 0b0001,
            payload: compressedPayload
        )
    }

    private static func buildFrame(
        messageType: UInt8,
        messageFlags: UInt8,
        serializationMethod: UInt8,
        compression: UInt8,
        sequence: Int? = nil,
        payload: Data
    ) throws -> Data {
        var frame = Data()
        frame.append(0x11)
        frame.append((messageType << 4) | messageFlags)
        frame.append((serializationMethod << 4) | compression)
        frame.append(0x00)

        if let sequence {
            var seq = Int32(sequence).bigEndian
            frame.append(Data(bytes: &seq, count: MemoryLayout<Int32>.size))
        }

        var payloadSize = Int32(payload.count).bigEndian
        frame.append(Data(bytes: &payloadSize, count: MemoryLayout<Int32>.size))
        frame.append(payload)
        return frame
    }
}

private enum DoubaoFrameParser {
    static func parse(_ data: Data) throws -> DoubaoParsedResponse {
        guard data.count >= 8 else {
            throw SessionFailureInfo(message: "豆包响应帧长度不合法。")
        }

        let messageType = (data[1] & 0xF0) >> 4
        let messageFlags = data[1] & 0x0F
        let serializationMethod = (data[2] & 0xF0) >> 4
        let compression = data[2] & 0x0F
        if messageType == 0b1111 {
            guard data.count >= 12 else {
                throw SessionFailureInfo(message: "豆包错误帧长度不合法。")
            }

            let errorCode = Int(data.readUInt32BE(at: 4))
            let payloadSize = Int(data.readUInt32BE(at: 8))
            let payload = Data(data.dropFirst(12).prefix(max(0, payloadSize)))
            let message: String
            if
                let object = try? JSONSerialization.jsonObject(with: payload) as? [String: Any],
                let readable = object["message"] as? String ?? object["error"] as? String
            {
                message = readable
            } else {
                message = String(data: payload, encoding: .utf8) ?? "错误码 \(errorCode)"
            }
            return DoubaoParsedResponse(transcript: nil, isTerminal: true, errorMessage: nil, transportError: message)
        }

        guard messageType == 0b1001 || messageType == 0b1011 else {
            return DoubaoParsedResponse(transcript: nil, isTerminal: false, errorMessage: nil, transportError: nil)
        }

        let decodedPayload = try extractResponsePayload(from: data, compression: compression)
        guard serializationMethod == 0b0001 || serializationMethod == 0b0000 else {
            throw SessionFailureInfo(message: "豆包返回了暂不支持的序列化格式。")
        }

        let jsonObject: Any
        do {
            jsonObject = try JSONSerialization.jsonObject(with: decodedPayload)
        } catch {
            let preview = String(data: decodedPayload.prefix(120), encoding: .utf8) ?? decodedPayload.prefix(24).map { String(format: "%02x", $0) }.joined()
            throw SessionFailureInfo(message: "豆包返回了非 JSON 数据：\(preview)")
        }

        guard let json = jsonObject as? [String: Any] else {
            throw SessionFailureInfo(message: "豆包响应不是对象结构。")
        }

        let code = json["code"] as? Int ?? 1000
        let message = json["message"] as? String
        if code != 1000, code != 0 {
            return DoubaoParsedResponse(transcript: nil, isTerminal: true, errorMessage: message ?? "请求失败", transportError: nil)
        }

        let isTerminal = messageFlags == 0b0011
        return DoubaoParsedResponse(
            transcript: DoubaoTranscriptPayload(resultValue: json["result"]),
            isTerminal: isTerminal,
            errorMessage: nil,
            transportError: nil
        )
    }

    private static func extractResponsePayload(from data: Data, compression: UInt8) throws -> Data {
        let candidateOffsets = [8, 4]
        var lastError: Error?

        for payloadSizeOffset in candidateOffsets {
            guard data.count >= payloadSizeOffset + 4 else { continue }

            let payloadSize = Int(data.readUInt32BE(at: payloadSizeOffset))
            let payloadStart = payloadSizeOffset + 4
            guard payloadSize >= 0, data.count >= payloadStart + payloadSize else { continue }

            let payload = Data(data[payloadStart..<(payloadStart + payloadSize)])
            do {
                let decoded = try (compression == 0b0001 ? payload.gzipDecompressed() : payload)
                if decoded.isLikelyJSONText || (try? JSONSerialization.jsonObject(with: decoded)) != nil {
                    return decoded
                }
            } catch {
                lastError = error
            }
        }

        throw lastError ?? SessionFailureInfo(message: "豆包响应负载位置无法判定。")
    }
}

struct DoubaoTranscriptPayload {
    let text: String?
    let rawText: String?
    let utterances: [DoubaoUtterance]

    var hasText: Bool {
        if let text, !text.isEmpty { return true }
        return utterances.contains { !$0.text.isEmpty }
    }

    var definiteCount: Int {
        utterances.filter(\.isDefinite).count
    }

    var canonicalText: String {
        if let text, !text.isEmpty {
            return text
        }

        return utterances
            .sorted(by: DoubaoUtterance.sortByTime)
            .map(\.text)
            .joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var rawCanonicalText: String {
        if let rawText, !rawText.isEmpty {
            return rawText
        }

        return utterances
            .sorted(by: DoubaoUtterance.sortByTime)
            .map(\.rawText)
            .joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    init?(resultValue: Any?) {
        if let resultObject = resultValue as? [String: Any] {
            self.init(resultObjects: [resultObject])
        } else if let resultObjects = resultValue as? [[String: Any]] {
            self.init(resultObjects: resultObjects)
        } else {
            return nil
        }
    }

    init?(resultObject: [String: Any]) {
        self.init(resultObjects: [resultObject])
    }

    private init?(resultObjects: [[String: Any]]) {
        let rawText = resultObjects
            .compactMap { $0["text"] as? String }
            .map(Self.trimRawText)
            .filter { !$0.isEmpty }
            .joined()

        let normalizedText = resultObjects
            .compactMap { $0["text"] as? String }
            .map(Self.sanitize)
            .filter { !$0.isEmpty }
            .joined()

        let utterances = resultObjects
            .flatMap { ($0["utterances"] as? [[String: Any]]) ?? [] }
            .compactMap(DoubaoUtterance.init(rawValue:))

        self.text = normalizedText.isEmpty ? nil : normalizedText
        self.rawText = rawText.isEmpty ? nil : rawText
        self.utterances = utterances

        guard hasText else { return nil }
    }

    private static func sanitize(_ text: String) -> String {
        TranscriptTextNormalizer.normalizeSpeechText(text)
    }

    private static func trimRawText(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct DoubaoUtterance {
    let text: String
    let rawText: String
    let startTime: Int?
    let endTime: Int?
    let isDefinite: Bool

    var hasTiming: Bool {
        startTime != nil && endTime != nil
    }

    init?(rawValue: [String: Any]) {
        let rawText = (rawValue["text"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let text = TranscriptTextNormalizer.normalizeSpeechText(rawText)
        guard !text.isEmpty else { return nil }

        self.text = text
        self.rawText = rawText
        self.startTime = rawValue["start_time"] as? Int
        self.endTime = rawValue["end_time"] as? Int
        self.isDefinite = (rawValue["definite"] as? Bool) == true
    }

    static func sortByTime(lhs: DoubaoUtterance, rhs: DoubaoUtterance) -> Bool {
        switch (lhs.startTime, rhs.startTime) {
        case let (left?, right?) where left != right:
            return left < right
        case (_?, nil):
            return true
        case (nil, _?):
            return false
        default:
            return (lhs.endTime ?? 0) < (rhs.endTime ?? 0)
        }
    }
}

private extension String {
    var escapedForDiagnosticLog: String {
        replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "\t", with: "\\t")
    }
}

private struct DoubaoParsedResponse {
    let transcript: DoubaoTranscriptPayload?
    let isTerminal: Bool
    let errorMessage: String?
    let transportError: String?
}

private struct DoubaoFullClientRequest: Encodable {
    struct UserPayload: Encodable {
        let uid: String
        let did: String
        let platform: String
        let sdkVersion: String
        let appVersion: String

        enum CodingKeys: String, CodingKey {
            case uid
            case did
            case platform
            case sdkVersion = "sdk_version"
            case appVersion = "app_version"
        }
    }

    struct AudioPayload: Encodable {
        let format: String
        let codec: String
        let rate: Int
        let bits: Int
        let channel: Int
        let language: String?
    }

    struct RequestPayload: Encodable {
        struct HotWordItem: Encodable {
            let hotWord: String
            let weight: Int

            enum CodingKeys: String, CodingKey {
                case hotWord = "hot_word"
                case weight
            }
        }

        let modelName: String
        let enableNonstream: Bool
        let showUtterances: Bool
        let resultType: String
        let enableITN: Bool
        let enableDDC: Bool
        let enablePunc: Bool
        let showSpeechRate: Bool
        let showVolume: Bool
        let enableLID: Bool
        let enableEmotionDetection: Bool
        let hotWordList: [HotWordItem]?

        enum CodingKeys: String, CodingKey {
            case modelName = "model_name"
            case enableNonstream = "enable_nonstream"
            case showUtterances = "show_utterances"
            case resultType = "result_type"
            case enableITN = "enable_itn"
            case enableDDC = "enable_ddc"
            case enablePunc = "enable_punc"
            case showSpeechRate = "show_speech_rate"
            case showVolume = "show_volume"
            case enableLID = "enable_lid"
            case enableEmotionDetection = "enable_emotion_detection"
            case hotWordList = "hot_word_list"
        }
    }

    let user: UserPayload
    let audio: AudioPayload
    let request: RequestPayload
}

private extension Data {
    var isLikelyJSONText: Bool {
        guard let first = firstNonWhitespaceByte else { return false }
        return first == 0x7B || first == 0x5B
    }

    var firstNonWhitespaceByte: UInt8? {
        first { !Self.whitespaceBytes.contains($0) }
    }

    func readUInt32BE(at offset: Int) -> UInt32 {
        precondition(offset + 4 <= count)
        return UInt32(self[offset]) << 24
            | UInt32(self[offset + 1]) << 16
            | UInt32(self[offset + 2]) << 8
            | UInt32(self[offset + 3])
    }

    var hexPreview: String {
        prefix(32).map { String(format: "%02x", $0) }.joined(separator: " ")
    }

    private static let whitespaceBytes: Set<UInt8> = [0x20, 0x09, 0x0A, 0x0D]

    func gzipCompressed() throws -> Data {
        var stream = z_stream()
        if isEmpty {
            stream.next_in = nil
            stream.avail_in = 0
        } else {
            stream.next_in = UnsafeMutablePointer<Bytef>(mutating: withUnsafeBytes { $0.bindMemory(to: Bytef.self).baseAddress! })
            stream.avail_in = uInt(count)
        }

        let windowBits = MAX_WBITS + 16
        guard deflateInit2_(&stream, Z_DEFAULT_COMPRESSION, Z_DEFLATED, windowBits, MAX_MEM_LEVEL, Z_DEFAULT_STRATEGY, ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size)) == Z_OK else {
            throw SessionFailureInfo(message: "豆包请求压缩失败。")
        }
        defer { deflateEnd(&stream) }

        var output = Data(count: 16_384)
        return try output.withUnsafeMutableBytes { outputBuffer in
            guard let baseAddress = outputBuffer.bindMemory(to: Bytef.self).baseAddress else {
                throw SessionFailureInfo(message: "豆包请求压缩失败。")
            }

            var compressed = Data()
            repeat {
                stream.next_out = baseAddress
                stream.avail_out = uInt(outputBuffer.count)
                let status = deflate(&stream, Z_FINISH)
                guard status == Z_OK || status == Z_STREAM_END else {
                    throw SessionFailureInfo(message: "豆包请求压缩失败。")
                }

                let produced = outputBuffer.count - Int(stream.avail_out)
                compressed.append(baseAddress, count: produced)

                if status == Z_STREAM_END {
                    break
                }
            } while stream.avail_out == 0

            return compressed
        }
    }

    func gzipDecompressed() throws -> Data {
        guard !isEmpty else { return Data() }

        var stream = z_stream()
        stream.next_in = UnsafeMutablePointer<Bytef>(mutating: withUnsafeBytes { $0.bindMemory(to: Bytef.self).baseAddress! })
        stream.avail_in = uInt(count)

        guard inflateInit2_(&stream, MAX_WBITS + 16, ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size)) == Z_OK else {
            throw SessionFailureInfo(message: "豆包响应解压失败。")
        }
        defer { inflateEnd(&stream) }

        var output = Data(count: 16_384)
        return try output.withUnsafeMutableBytes { outputBuffer in
            guard let baseAddress = outputBuffer.bindMemory(to: Bytef.self).baseAddress else {
                throw SessionFailureInfo(message: "豆包响应解压失败。")
            }

            var decompressed = Data()
            while true {
                stream.next_out = baseAddress
                stream.avail_out = uInt(outputBuffer.count)
                let status = inflate(&stream, Z_NO_FLUSH)
                guard status == Z_OK || status == Z_STREAM_END else {
                    throw SessionFailureInfo(message: "豆包响应解压失败。")
                }

                let produced = outputBuffer.count - Int(stream.avail_out)
                decompressed.append(baseAddress, count: produced)

                if status == Z_STREAM_END {
                    break
                }
            }

            return decompressed
        }
    }
}
