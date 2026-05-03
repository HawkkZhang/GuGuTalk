import Foundation
import os

actor LLMClient {
    private static let logger = Logger(subsystem: "com.end.DesktopVoiceInput", category: "LLMClient")
    private let session: URLSession

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        self.session = URLSession(configuration: config)
    }

    func complete(system: String, user: String, config: LLMProviderConfig) async throws -> String {
        let trimmed = config.trimmed
        switch trimmed.protocolType {
        case .openAICompatible:
            return try await openAIComplete(system: system, user: user, config: trimmed)
        case .anthropic:
            return try await anthropicComplete(system: system, user: user, config: trimmed)
        }
    }

    private func openAIComplete(system: String, user: String, config: LLMProviderConfig) async throws -> String {
        let endpoint = config.endpoint.hasSuffix("/")
            ? config.endpoint + "v1/chat/completions"
            : config.endpoint + "/v1/chat/completions"

        guard let url = URL(string: endpoint) else {
            throw LLMError.invalidEndpoint(config.endpoint)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")

        let body: [String: Any] = [
            "model": config.model,
            "messages": [
                ["role": "system", "content": system],
                ["role": "user", "content": user]
            ],
            "temperature": 0.3
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? ""
            Self.logger.error("OpenAI API error. status=\(httpResponse.statusCode) body=\(errorBody, privacy: .public)")
            throw LLMError.apiError(statusCode: httpResponse.statusCode, message: extractErrorMessage(from: data) ?? "HTTP \(httpResponse.statusCode)")
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw LLMError.invalidResponse
        }

        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func anthropicComplete(system: String, user: String, config: LLMProviderConfig) async throws -> String {
        let endpoint = config.endpoint.hasSuffix("/")
            ? config.endpoint + "v1/messages"
            : config.endpoint + "/v1/messages"

        guard let url = URL(string: endpoint) else {
            throw LLMError.invalidEndpoint(config.endpoint)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(config.apiKey, forHTTPHeaderField: "x-api-key")
        request.addValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let body: [String: Any] = [
            "model": config.model,
            "max_tokens": 4096,
            "system": system,
            "messages": [
                ["role": "user", "content": user]
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? ""
            Self.logger.error("Anthropic API error. status=\(httpResponse.statusCode) body=\(errorBody, privacy: .public)")
            throw LLMError.apiError(statusCode: httpResponse.statusCode, message: extractErrorMessage(from: data) ?? "HTTP \(httpResponse.statusCode)")
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let firstBlock = content.first,
              let text = firstBlock["text"] as? String else {
            throw LLMError.invalidResponse
        }

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func extractErrorMessage(from data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        if let error = json["error"] as? [String: Any], let message = error["message"] as? String {
            return message
        }
        return json["message"] as? String ?? json["error"] as? String
    }
}

enum LLMError: LocalizedError {
    case invalidEndpoint(String)
    case invalidResponse
    case apiError(statusCode: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .invalidEndpoint(let url): "LLM 端点地址无效：\(url)"
        case .invalidResponse: "LLM 返回了无法解析的响应"
        case .apiError(_, let message): "LLM 请求失败：\(message)"
        }
    }
}
