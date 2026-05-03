import Foundation

enum LLMProtocolType: String, Codable, CaseIterable, Identifiable {
    case openAICompatible
    case anthropic

    var id: String { rawValue }

    var title: String {
        switch self {
        case .openAICompatible: "OpenAI 兼容"
        case .anthropic: "Anthropic"
        }
    }

    var subtitle: String {
        switch self {
        case .openAICompatible: "OpenAI、DeepSeek、千问、豆包、Kimi、智谱、Minimax、Gemini"
        case .anthropic: "Claude"
        }
    }
}

struct LLMProviderConfig: Codable, Equatable {
    var protocolType: LLMProtocolType = .openAICompatible
    var endpoint: String = ""
    var apiKey: String = ""
    var model: String = ""

    var isConfigured: Bool {
        !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !endpoint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var trimmed: LLMProviderConfig {
        LLMProviderConfig(
            protocolType: protocolType,
            endpoint: endpoint.trimmingCharacters(in: .whitespacesAndNewlines),
            apiKey: apiKey.trimmingCharacters(in: .whitespacesAndNewlines),
            model: model.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }
}
