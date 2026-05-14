import XCTest
import AVFoundation
@testable import DesktopVoiceInput

final class DesktopVoiceInputTests: XCTestCase {
    func testPostProcessorDoesNotAddTerminalPunctuation() {
        let processor = TranscriptPostProcessor()
        XCTAssertEqual(processor.finalize("你好 今天过得怎么样"), "你好今天过得怎么样")
    }

    func testPostProcessorPreservesExistingPunctuation() {
        let processor = TranscriptPostProcessor()
        XCTAssertEqual(processor.finalize("会议结束了吗？"), "会议结束了吗？")
    }

    func testPostProcessorCollapsesWhitespace() {
        let processor = TranscriptPostProcessor()
        XCTAssertEqual(processor.finalize("  明天   上午  十点   开会  "), "明天上午十点开会")
    }

    func testPostProcessorRemovesChinesePauseSpaces() {
        let processor = TranscriptPostProcessor()
        XCTAssertEqual(processor.finalize("这个 过程 中 就 会 有 空格"), "这个过程中就会有空格")
    }

    func testPostProcessorPreservesEnglishWordSpaces() {
        let processor = TranscriptPostProcessor()
        XCTAssertEqual(processor.finalize("打开 OpenAI Cloud 控制台"), "打开 OpenAI Cloud 控制台")
    }

    func testRemoveTrailingPunctuationAfterWhitespace() {
        let result = TextTransform.removeTrailingPunctuation.apply(to: "今天先这样。   \n")
        XCTAssertEqual(result, "今天先这样")
    }

    func testRemoveTrailingPunctuationKeepsQuestionAndExclamationMarks() {
        let result = TextTransform.removeTrailingPunctuation.apply(to: "真的吗？！")
        XCTAssertEqual(result, "真的吗？！")
    }

    func testRemoveTrailingPunctuationRemovesOnlyTerminalPeriods() {
        let result = TextTransform.removeTrailingPunctuation.apply(to: "今天先这样。。")
        XCTAssertEqual(result, "今天先这样")
    }

    func testRemoveTrailingPunctuationKeepsMiddlePunctuation() {
        let result = TextTransform.removeTrailingPunctuation.apply(to: "你好，今天先这样。")
        XCTAssertEqual(result, "你好，今天先这样")
    }

    func testDoubaoTranscriptPayloadUsesResultText() {
        let payload = DoubaoTranscriptPayload(resultObject: [
            "text": "这是豆包官方推荐的累积完整文本。"
        ])
        XCTAssertEqual(payload?.text, "这是豆包官方推荐的累积完整文本。")
    }

    func testDoubaoTranscriptPayloadNormalizesChinesePauseSpaces() {
        let payload = DoubaoTranscriptPayload(resultObject: [
            "text": "这个 过程 中 就 会 有 空格"
        ])
        XCTAssertEqual(payload?.canonicalText, "这个过程中就会有空格")
        XCTAssertEqual(payload?.rawCanonicalText, "这个 过程 中 就 会 有 空格")
    }

    func testDoubaoTranscriptPayloadReturnsNilWhenEmpty() {
        let payload = DoubaoTranscriptPayload(resultObject: [
            "text": "   "
        ])
        XCTAssertNil(payload)
    }

    func testDoubaoTranscriptPayloadReadsUtterances() {
        let payload = DoubaoTranscriptPayload(resultObject: [
            "text": "整段文本",
            "utterances": [
                ["definite": true, "start_time": 0, "end_time": 500, "text": "已经确定，"],
                ["definite": false, "start_time": 500, "end_time": 900, "text": "还在识别"]
            ]
        ])

        XCTAssertEqual(payload?.utterances.count, 2)
        XCTAssertEqual(payload?.definiteCount, 1)
    }

    func testDoubaoTranscriptPayloadReadsResultList() {
        let payload = DoubaoTranscriptPayload(resultValue: [
            [
                "text": "列表结构",
                "utterances": [
                    ["definite": true, "start_time": 0, "end_time": 500, "text": "列表结构"]
                ]
            ]
        ])

        XCTAssertEqual(payload?.text, "列表结构")
        XCTAssertEqual(payload?.utterances.count, 1)
    }

    func testDoubaoCanonicalTextPrefersServiceFullText() {
        let payload = DoubaoTranscriptPayload(resultObject: [
            "text": "服务端完整结果",
            "utterances": [
                ["definite": true, "start_time": 0, "end_time": 800, "text": "局部分句"]
            ]
        ])

        XCTAssertEqual(payload?.canonicalText, "服务端完整结果")
    }

    func testDoubaoCanonicalTextFallsBackToTimeSortedUtterances() {
        let payload = DoubaoTranscriptPayload(resultObject: [
            "utterances": [
                ["definite": false, "start_time": 800, "end_time": 1200, "text": "颜色"],
                ["definite": true, "start_time": 0, "end_time": 800, "text": "整个应用的"]
            ]
        ])

        XCTAssertEqual(payload?.canonicalText, "整个应用的颜色")
    }

    func testDoubaoFinalRepairKeepsDroppedStablePrefix() {
        let repaired = DoubaoTranscriptRepair.recoverFinalText(
            current: "之前还挺好用的。",
            previous: "Gemini 之前还"
        )

        XCTAssertTrue(repaired.didRecover)
        XCTAssertEqual(repaired.text, "Gemini 之前还挺好用的。")
    }

    func testDoubaoFinalRepairDoesNotChangeNormalFullFinal() {
        let repaired = DoubaoTranscriptRepair.recoverFinalText(
            current: "Gemini 之前还挺好用的。",
            previous: "Gemini 之前还"
        )

        XCTAssertFalse(repaired.didRecover)
        XCTAssertEqual(repaired.text, "Gemini 之前还挺好用的。")
    }

    func testDoubaoFinalRepairRequiresMeaningfulOverlap() {
        let repaired = DoubaoTranscriptRepair.recoverFinalText(
            current: "还挺好用的。",
            previous: "Gemini 之前还"
        )

        XCTAssertFalse(repaired.didRecover)
        XCTAssertEqual(repaired.text, "还挺好用的。")
    }

    func testAudioPrerollBufferKeepsRecentAudioWithinDurationLimit() {
        var buffer = AudioPrerollBuffer(maxDuration: 1.0)

        buffer.append(makeAudioChunk(duration: 0.4, level: 0.1))
        buffer.append(makeAudioChunk(duration: 0.4, level: 0.2))
        buffer.append(makeAudioChunk(duration: 0.4, level: 0.3))

        XCTAssertEqual(buffer.chunks.count, 2)
        XCTAssertEqual(buffer.chunks.first?.audioLevel, 0.2)
        XCTAssertEqual(buffer.chunks.last?.audioLevel, 0.3)
        XCTAssertLessThanOrEqual(buffer.duration, 1.0)
    }

    func testAudioPrerollBufferDrainPreservesOrderAndClearsBuffer() {
        var buffer = AudioPrerollBuffer(maxDuration: 2.0)

        buffer.append(makeAudioChunk(duration: 0.25, level: 0.1))
        buffer.append(makeAudioChunk(duration: 0.25, level: 0.2))

        let drained = buffer.drain()

        XCTAssertEqual(drained.map(\.audioLevel), [0.1, 0.2])
        XCTAssertTrue(buffer.isEmpty)
        XCTAssertEqual(buffer.duration, 0)
    }

    private func makeAudioChunk(duration: TimeInterval, level: Float) -> AudioChunk {
        let sampleRate = 16_000.0
        let frameCount = AVAudioFrameCount(duration * sampleRate)
        let format = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: sampleRate, channels: 1, interleaved: false)!
        let nativeBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        nativeBuffer.frameLength = frameCount
        return AudioChunk(
            pcmData: Data(count: Int(frameCount) * MemoryLayout<Int16>.size),
            sampleRate: sampleRate,
            channels: 1,
            audioLevel: level,
            nativeBuffer: nativeBuffer
        )
    }
}
