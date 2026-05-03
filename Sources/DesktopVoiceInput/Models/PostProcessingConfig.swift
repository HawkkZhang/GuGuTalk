import Foundation

enum PunctuationMode: String, CaseIterable, Identifiable, Codable {
    case keep
    case remove
    case replaceWithSpace
    case removeTrailing

    var id: String { rawValue }

    var title: String {
        switch self {
        case .keep: "保留原样"
        case .remove: "去掉标点"
        case .replaceWithSpace: "空格代替"
        case .removeTrailing: "去句尾句号"
        }
    }

    var rules: [TextTransform] {
        switch self {
        case .keep: []
        case .remove: [.removePunctuation, .collapseWhitespace, .trimWhitespace]
        case .replaceWithSpace: [.replacePunctuation(replacement: " "), .collapseWhitespace, .trimWhitespace]
        case .removeTrailing: [.removeTrailingPunctuation, .trimWhitespace]
        }
    }
}

enum TextTransform: Codable, Equatable, Identifiable {
    case removePunctuation
    case replacePunctuation(replacement: String)
    case removeTrailingPunctuation
    case addTrailingPunctuation(mark: String)
    case collapseWhitespace
    case trimWhitespace
    case regexReplace(pattern: String, replacement: String)

    var id: String {
        switch self {
        case .removePunctuation: "removePunctuation"
        case .replacePunctuation(let r): "replacePunctuation:\(r)"
        case .removeTrailingPunctuation: "removeTrailingPunctuation"
        case .addTrailingPunctuation(let m): "addTrailingPunctuation:\(m)"
        case .collapseWhitespace: "collapseWhitespace"
        case .trimWhitespace: "trimWhitespace"
        case .regexReplace(let p, let r): "regexReplace:\(p):\(r)"
        }
    }

    var displayName: String {
        switch self {
        case .removePunctuation: "移除所有标点"
        case .replacePunctuation(let r): "标点替换为「\(r)」"
        case .removeTrailingPunctuation: "去句尾标点"
        case .addTrailingPunctuation(let m): "加句尾「\(m)」"
        case .collapseWhitespace: "合并连续空格"
        case .trimWhitespace: "去首尾空格"
        case .regexReplace(let p, _): "正则替换：\(p)"
        }
    }

    func apply(to text: String) -> String {
        switch self {
        case .removePunctuation:
            return text.replacingOccurrences(
                of: "[\\p{P}\\p{S}]",
                with: "",
                options: .regularExpression
            )
        case .replacePunctuation(let replacement):
            return text.replacingOccurrences(
                of: "[\\p{P}\\p{S}]",
                with: replacement,
                options: .regularExpression
            )
        case .removeTrailingPunctuation:
            var result = text
            while let last = result.unicodeScalars.last,
                  CharacterSet.punctuationCharacters.union(.symbols).contains(last) {
                result = String(result.dropLast())
            }
            return result
        case .addTrailingPunctuation(let mark):
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return text }
            if let last = trimmed.unicodeScalars.last,
               CharacterSet.punctuationCharacters.contains(last) {
                return text
            }
            return text + mark
        case .collapseWhitespace:
            return text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        case .trimWhitespace:
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        case .regexReplace(let pattern, let replacement):
            return text.replacingOccurrences(of: pattern, with: replacement, options: .regularExpression)
        }
    }
}

struct PostProcessingConfig: Codable {
    var isEnabled: Bool = false
    var globalPipeline: ProcessingPipeline = ProcessingPipeline()
    var appPipelines: [AppPipeline] = []

    struct ProcessingPipeline: Codable {
        var rules: [TextTransform] = []
        var llmPrompt: String?

        var needsLLM: Bool { llmPrompt != nil && !(llmPrompt?.isEmpty ?? true) }
    }

    struct AppPipeline: Codable, Identifiable {
        var id: String { appIdentifier }
        var appIdentifier: String
        var displayName: String
        var pipeline: ProcessingPipeline
    }

    func pipeline(forBundleID bundleID: String?, appName: String?) -> ProcessingPipeline {
        if let bundleID, let match = appPipelines.first(where: { $0.appIdentifier == bundleID }) {
            return match.pipeline
        }
        if let appName, let match = appPipelines.first(where: {
            $0.displayName.localizedCaseInsensitiveCompare(appName) == .orderedSame
        }) {
            return match.pipeline
        }
        return globalPipeline
    }

    static func applyRules(_ rules: [TextTransform], to text: String) -> String {
        rules.reduce(text) { result, transform in transform.apply(to: result) }
    }
}

enum PostProcessingPreset: String, CaseIterable, Identifiable, Codable {
    case correction
    case formal
    case bulletPoints

    var id: String { rawValue }

    var title: String {
        switch self {
        case .correction: "纠错"
        case .formal: "正式化"
        case .bulletPoints: "列表"
        }
    }

    var defaultPrompt: String {
        switch self {
        case .correction:
            "你是一个语音识别纠错助手。只修正明显的语音识别错误（同音字、漏字、多字），保持原意和语气完全不变。直接输出修正后的文本，不要解释。"
        case .formal:
            "你是一个文本润色助手。将口语化表达转为正式书面语，保持原意不变。直接输出润色后的文本，不要解释。"
        case .bulletPoints:
            "你是一个文本格式化助手。将输入内容整理为 markdown 无序列表格式（每个要点一行，以 - 开头）。直接输出格式化后的文本，不要解释。"
        }
    }

    var needsLLM: Bool { true }
}
