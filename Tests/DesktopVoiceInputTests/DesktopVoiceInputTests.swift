import XCTest
@testable import DesktopVoiceInput

final class DesktopVoiceInputTests: XCTestCase {
    func testPostProcessorAddsTerminalPunctuation() {
        let processor = TranscriptPostProcessor()
        XCTAssertEqual(processor.finalize("你好 今天过得怎么样"), "你好 今天过得怎么样。")
    }

    func testPostProcessorPreservesExistingPunctuation() {
        let processor = TranscriptPostProcessor()
        XCTAssertEqual(processor.finalize("会议结束了吗？"), "会议结束了吗？")
    }

    func testPostProcessorCollapsesWhitespace() {
        let processor = TranscriptPostProcessor()
        XCTAssertEqual(processor.finalize("  明天   上午  十点   开会  "), "明天 上午 十点 开会。")
    }
}
