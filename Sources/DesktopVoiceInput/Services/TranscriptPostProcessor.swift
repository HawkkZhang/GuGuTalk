import Foundation

struct TranscriptPostProcessor {
    func finalize(_ text: String) -> String {
        var value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return value }

        value = collapseWhitespace(in: value)
        value = normalizeChineseSpacing(in: value)

        if needsTerminalPunctuation(value) {
            value.append("。")
        }

        return value
    }

    private func collapseWhitespace(in text: String) -> String {
        text.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
    }

    private func normalizeChineseSpacing(in text: String) -> String {
        text
            .replacingOccurrences(of: " ，", with: "，")
            .replacingOccurrences(of: " 。", with: "。")
            .replacingOccurrences(of: " ？", with: "？")
            .replacingOccurrences(of: " ！", with: "！")
            .replacingOccurrences(of: " ：", with: "：")
    }

    private func needsTerminalPunctuation(_ text: String) -> Bool {
        guard let last = text.last else { return false }
        return !"。！？!?…".contains(last)
    }
}
