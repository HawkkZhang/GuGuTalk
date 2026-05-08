import XCTest
@testable import DesktopVoiceInput

final class DesktopVoiceInputTests: XCTestCase {
    func testPostProcessorDoesNotAddTerminalPunctuation() {
        let processor = TranscriptPostProcessor()
        XCTAssertEqual(processor.finalize("你好 今天过得怎么样"), "你好 今天过得怎么样")
    }

    func testPostProcessorPreservesExistingPunctuation() {
        let processor = TranscriptPostProcessor()
        XCTAssertEqual(processor.finalize("会议结束了吗？"), "会议结束了吗？")
    }

    func testPostProcessorCollapsesWhitespace() {
        let processor = TranscriptPostProcessor()
        XCTAssertEqual(processor.finalize("  明天   上午  十点   开会  "), "明天 上午 十点 开会")
    }

    func testRemoveTrailingPunctuationAfterWhitespace() {
        let result = TextTransform.removeTrailingPunctuation.apply(to: "今天先这样。   \n")
        XCTAssertEqual(result, "今天先这样")
    }

    func testRemoveTrailingPunctuationRemovesMultipleMarks() {
        let result = TextTransform.removeTrailingPunctuation.apply(to: "真的吗？！")
        XCTAssertEqual(result, "真的吗")
    }

    func testRemoveTrailingPunctuationKeepsMiddlePunctuation() {
        let result = TextTransform.removeTrailingPunctuation.apply(to: "你好，今天先这样。")
        XCTAssertEqual(result, "你好，今天先这样")
    }

    func testDoubaoStabilizerDropsRepeatedOldHypothesisPrefix() {
        let result = DoubaoTranscriptStabilizer.stabilize(
            incoming: "一指，请问 open一指请问 OpenAI Cloud 这种",
            previous: "一指，请问 open"
        )
        XCTAssertEqual(result, "一指请问 OpenAI Cloud 这种")
    }

    func testDoubaoStabilizerCollapsesAdjacentRepeat() {
        let result = DoubaoTranscriptStabilizer.stabilize(
            incoming: "现在输入没问题了现在输入没问题了，但是会有重复",
            previous: nil
        )
        XCTAssertEqual(result, "现在输入没问题了，但是会有重复")
    }

    func testDoubaoStabilizerCollapsesShortAdjacentRepeat() {
        let result = DoubaoTranscriptStabilizer.stabilize(
            incoming: "现在现在可以继续输入",
            previous: nil
        )
        XCTAssertEqual(result, "现在可以继续输入")
    }

    func testDoubaoStabilizerKeepsSingleCharacterReduplication() {
        let result = DoubaoTranscriptStabilizer.stabilize(
            incoming: "你可以试试这个功能",
            previous: nil
        )
        XCTAssertEqual(result, "你可以试试这个功能")
    }

    func testDoubaoStabilizerKeepsNormalContinuation() {
        let result = DoubaoTranscriptStabilizer.stabilize(
            incoming: "今天我们继续优化语音输入体验",
            previous: "今天我们继续优化"
        )
        XCTAssertEqual(result, "今天我们继续优化语音输入体验")
    }

    func testDoubaoTranscriptPayloadSplitsFinalizedAndActiveUtterances() {
        let payload = DoubaoTranscriptPayload(resultObject: [
            "text": "这是已经确定的，这句还在识别",
            "utterances": [
                ["definite": true, "text": "这是已经确定的，"],
                ["definite": false, "text": "这句还在识别"]
            ]
        ])

        XCTAssertEqual(payload?.finalizedText, "这是已经确定的，")
        XCTAssertEqual(payload?.activeText, "这句还在识别")
        XCTAssertTrue(payload?.hasFinalizedUtterance == true)
    }
}
