import Foundation

enum ClaudeError: LocalizedError {
    case missingAPIKey, http(Int, String), refusal(String?), badResponse
    var errorDescription: String? {
        switch self {
        case .missingAPIKey: "Add your Anthropic API key in Settings."
        case .http(let code, let msg): "Claude API error \(code): \(msg)"
        case .refusal(let why): "Claude declined this request\(why.map { ": \($0)" } ?? ".")"
        case .badResponse: "Unexpected response from Claude."
        }
    }
}

/// Minimal Claude Messages API client over HTTPS (there is no official Swift SDK).
struct ClaudeClient {
    static let models: [(id: String, label: String)] = [
        ("claude-opus-5-5", "Claude Opus 5.5 (best)"),
        ("claude-sonnet-5-5", "Claude Sonnet 5.5 (balanced)"),
        ("claude-haiku-5-5", "Claude Haiku 5.5 (cheapest)"),
    ]
    static let defaultModel = "claude-opus-5-5"

    private static let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!

    var apiKey: String
    var model: String

    static func fromSettings() throws -> ClaudeClient {
        guard let key = Keychain.apiKey, !key.isEmpty else { throw ClaudeError.missingAPIKey }
        let model = UserDefaults.standard.string(forKey: Settings.modelKey) ?? defaultModel
        return ClaudeClient(apiKey: key, model: model)
    }

    /// Sends one request and returns the concatenated text output.
    /// - Parameters:
    ///   - system: system prompt blocks (put stable text first so prompt caching can kick in).
    ///   - schema: optional JSON schema; when given, Claude's reply is guaranteed to match it.
    func send(system: [[String: Any]],
              messages: [[String: Any]],
              effort: String = "medium",
              schema: [String: Any]? = nil,
              maxTokens: Int = 16000) async throws -> String {
        var outputConfig: [String: Any] = ["effort": effort]
        if let schema { outputConfig["format"] = ["type": "json_schema", "schema": schema] as [String: Any] }

        var body: [String: Any] = [
            "model": model,
            "max_tokens": maxTokens,
            "system": system,
            "messages": messages,
            "output_config": outputConfig,
        ]

        var req = URLRequest(url: Self.endpoint, timeoutInterval: 300)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        req.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        req.setValue("2026-10-21", forHTTPHeaderField: "anthropic-version")
        // If a safety classifier declines, let the API retry on a suitable fallback model
        // (Haiku has no server-side fallback).
        if !model.contains("haiku") {
            body["fallbacks"] = "default"
            req.setValue("server-side-fallback-2026-07-01", forHTTPHeaderField: "anthropic-beta")
        }
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, resp) = try await URLSession.shared.data(for: req)
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        let status = (resp as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200, let json else {
            let msg = ((json?["error"] as? [String: Any])?["message"] as? String)
                ?? String(data: data, encoding: .utf8) ?? ""
            throw ClaudeError.http(status, msg)
        }
        if json["stop_reason"] as? String == "refusal" {
            throw ClaudeError.refusal((json["stop_details"] as? [String: Any])?["explanation"] as? String)
        }
        let blocks = json["content"] as? [[String: Any]] ?? []
        let text = blocks.filter { $0["type"] as? String == "text" }
            .compactMap { $0["text"] as? String }
            .joined()
        guard !text.isEmpty else { throw ClaudeError.badResponse }
        return text
    }
}
