import Foundation

struct TranscriptPostProcessor {
    func finalize(_ text: String) -> String {
        TranscriptTextNormalizer.normalizeSpeechText(text)
    }
}

enum TranscriptTextNormalizer {
    static func normalizeSpeechText(_ text: String) -> String {
        var value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return value }

        value = value.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        value = value.replacingOccurrences(
            of: #"(?<=[\u4E00-\u9FFF])\s+(?=[\u4E00-\u9FFF])"#,
            with: "",
            options: .regularExpression
        )
        value = value.replacingOccurrences(
            of: #"(?<=[，。！？；：、])\s+(?=[\u4E00-\u9FFF])"#,
            with: "",
            options: .regularExpression
        )
        value = value.replacingOccurrences(
            of: #"\s+(?=[，。！？；：、])"#,
            with: "",
            options: .regularExpression
        )
        value = value.replacingOccurrences(
            of: #"(?<=[（《「『【])\s+"#,
            with: "",
            options: .regularExpression
        )
        value = value.replacingOccurrences(
            of: #"\s+(?=[））》」』】])"#,
            with: "",
            options: .regularExpression
        )

        return value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
