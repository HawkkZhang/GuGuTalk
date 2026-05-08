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

    func testDoubaoTranscriptPayloadUsesResultText() {
        let payload = DoubaoTranscriptPayload(resultObject: [
            "text": "这是豆包官方推荐的累积完整文本。"
        ])
        XCTAssertEqual(payload?.text, "这是豆包官方推荐的累积完整文本。")
    }

    func testDoubaoTranscriptPayloadReturnsNilWhenEmpty() {
        let payload = DoubaoTranscriptPayload(resultObject: [
            "text": "   "
        ])
        XCTAssertNil(payload)
    }
}
