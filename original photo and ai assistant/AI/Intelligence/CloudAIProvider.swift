//
//  CloudAIProvider.swift
//  AI Camera Coach — Intelligence layer
//
//  HTTP clients for OpenAI and Anthropic. Both engines use the USER'S OWN
//  API key — the app never proxies through a developer-managed key.
//
//  No third-party HTTP libraries. URLSession only. All requests honour
//  cancellation; in-flight requests are cancelled when forensic mode is
//  toggled on mid-session.
//

import Foundation

// MARK: - Shared

nonisolated struct CloudModelSelection: Sendable, Hashable, Codable {
    var openAIModel: String = "gpt-4o-mini"
    var anthropicModel: String = "claude-haiku-4-5"
}

nonisolated private let kCoachingSystemPrompt = """
You are a warm, concise photography coach.
Speak in plain language. Never use technical terms like ISO, EV,
aperture, shutter speed, histograms, or dynamic range.
Give at most three short tips, written as imperative sentences
(e.g. "Move closer.", "Wait for the smile.").
Be encouraging. Maximum 60 words.
"""

// MARK: - OpenAI

actor OpenAICloudEngine: AIEngine {

    let name = "OpenAI"
    let runsOnDevice = false
    let capabilities: Set<AICapability> = [.coachingAdvice, .scoreExplanation, .photoCaption]

    private let session: URLSession
    private let apiKeyProvider: @Sendable () -> String?
    private let modelProvider: @Sendable () -> String

    init(apiKeyProvider: @escaping @Sendable () -> String?,
         modelProvider: @escaping @Sendable () -> String) {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 45
        self.session = URLSession(configuration: config)
        self.apiKeyProvider = apiKeyProvider
        self.modelProvider = modelProvider
    }

    nonisolated var provenance: AIProvenance { .openAI(model: modelProvider()) }

    func isAvailable() async -> Bool {
        guard let key = apiKeyProvider(), !key.isEmpty else { return false }
        return true
    }

    func coachingAdvice(scene: SceneSummary) async throws -> AIResponse {
        let user = "Scene snapshot:\n\(scene.promptDescription)\n\nGive up to three short tips."
        let text = try await chat(systemPrompt: kCoachingSystemPrompt, userPrompt: user)
        return AIResponse(text: text, provenance: provenance)
    }

    func coachingAdvice(scene: SceneSummary, imageJPEG: Data) async throws -> AIResponse {
        // Use the vision capability: the model sees the actual frame +
        // the structured scene summary. Cap the image at a reasonable
        // size to control upload cost.
        let dataURL = "data:image/jpeg;base64,\(imageJPEG.base64EncodedString())"
        let payload: [String: Any] = [
            "model": modelProvider(),
            "messages": [
                ["role": "system", "content": kCoachingSystemPrompt],
                ["role": "user", "content": [
                    ["type": "text",
                     "text": "Scene snapshot:\n\(scene.promptDescription)\n\nLook at this photo. Give up to three short tips that reference something you can actually see."],
                    ["type": "image_url", "image_url": ["url": dataURL]]
                ] as [Any]]
            ],
            "max_tokens": 220,
            "temperature": 0.5
        ]
        let text = try await postChatCompletion(payload: payload)
        return AIResponse(text: text, provenance: provenance)
    }

    func scoreExplanation(score: PhotoScore, scene: SceneSummary) async throws -> AIResponse {
        let breakdown = score.breakdown
            .sorted { $0.key < $1.key }
            .map { "\($0.key) \($0.value)" }
            .joined(separator: ", ")
        let user = """
        The photo score is \(score.total)/100. Component scores: \(breakdown).
        Scene snapshot:
        \(scene.promptDescription)

        In two sentences, explain the score and end with one specific action.
        """
        let text = try await chat(systemPrompt: kCoachingSystemPrompt, userPrompt: user)
        return AIResponse(text: text, provenance: provenance)
    }

    func photoCaption(imageJPEG: Data, mode: CaptureMode) async throws -> AIResponse {
        let dataURL = "data:image/jpeg;base64,\(imageJPEG.base64EncodedString())"
        let payload: [String: Any] = [
            "model": modelProvider(),
            "messages": [
                ["role": "system", "content": "Write a single short, vivid caption (max 14 words). No hashtags."],
                ["role": "user", "content": [
                    ["type": "text", "text": "Caption this photo for a \(mode.title) shot."],
                    ["type": "image_url", "image_url": ["url": dataURL]]
                ] as [Any]]
            ],
            "max_tokens": 80,
            "temperature": 0.6
        ]
        let text = try await postChatCompletion(payload: payload)
        return AIResponse(text: text, provenance: provenance)
    }

    // MARK: -

    private func chat(systemPrompt: String, userPrompt: String) async throws -> String {
        let payload: [String: Any] = [
            "model": modelProvider(),
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userPrompt]
            ],
            "max_tokens": 200,
            "temperature": 0.5
        ]
        return try await postChatCompletion(payload: payload)
    }

    private func postChatCompletion(payload: [String: Any]) async throws -> String {
        guard let key = apiKeyProvider(), !key.isEmpty else {
            throw AIError.invalidAPIKey(provider: "OpenAI")
        }
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            throw AIError.networkFailure(underlying: "bad URL")
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        req.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: req)
        } catch {
            throw AIError.networkFailure(underlying: error.localizedDescription)
        }
        try Task.checkCancellation()

        guard let http = response as? HTTPURLResponse else {
            throw AIError.networkFailure(underlying: "no HTTP response")
        }
        switch http.statusCode {
        case 200...299: break
        case 401:       throw AIError.invalidAPIKey(provider: "OpenAI")
        case 429:       throw AIError.rateLimited(provider: "OpenAI")
        default:
            let snippet = String(data: data, encoding: .utf8)?.prefix(160) ?? ""
            throw AIError.networkFailure(underlying: "HTTP \(http.statusCode): \(snippet)")
        }

        guard
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let choices = json["choices"] as? [[String: Any]],
            let first = choices.first,
            let message = first["message"] as? [String: Any],
            let content = message["content"] as? String
        else {
            throw AIError.decoding("missing 'choices[0].message.content'")
        }
        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Anthropic

actor AnthropicCloudEngine: AIEngine {

    let name = "Anthropic"
    let runsOnDevice = false
    let capabilities: Set<AICapability> = [.coachingAdvice, .scoreExplanation, .photoCaption]

    private let session: URLSession
    private let apiKeyProvider: @Sendable () -> String?
    private let modelProvider: @Sendable () -> String

    init(apiKeyProvider: @escaping @Sendable () -> String?,
         modelProvider: @escaping @Sendable () -> String) {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 45
        self.session = URLSession(configuration: config)
        self.apiKeyProvider = apiKeyProvider
        self.modelProvider = modelProvider
    }

    nonisolated var provenance: AIProvenance { .anthropic(model: modelProvider()) }

    func isAvailable() async -> Bool {
        guard let key = apiKeyProvider(), !key.isEmpty else { return false }
        return true
    }

    func coachingAdvice(scene: SceneSummary) async throws -> AIResponse {
        let user = "Scene snapshot:\n\(scene.promptDescription)\n\nGive up to three short tips."
        let text = try await messages(system: kCoachingSystemPrompt, user: user)
        return AIResponse(text: text, provenance: provenance)
    }

    func coachingAdvice(scene: SceneSummary, imageJPEG: Data) async throws -> AIResponse {
        let payload: [String: Any] = [
            "model": modelProvider(),
            "max_tokens": 220,
            "system": kCoachingSystemPrompt,
            "messages": [
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "image",
                            "source": [
                                "type": "base64",
                                "media_type": "image/jpeg",
                                "data": imageJPEG.base64EncodedString()
                            ]
                        ],
                        [
                            "type": "text",
                            "text": "Scene snapshot:\n\(scene.promptDescription)\n\nLook at this photo. Give up to three short tips that reference something you can actually see."
                        ]
                    ] as [Any]
                ]
            ]
        ]
        let text = try await postMessages(payload: payload)
        return AIResponse(text: text, provenance: provenance)
    }

    func scoreExplanation(score: PhotoScore, scene: SceneSummary) async throws -> AIResponse {
        let breakdown = score.breakdown
            .sorted { $0.key < $1.key }
            .map { "\($0.key) \($0.value)" }
            .joined(separator: ", ")
        let user = """
        The photo score is \(score.total)/100. Component scores: \(breakdown).
        Scene snapshot:
        \(scene.promptDescription)

        In two sentences, explain the score and end with one specific action.
        """
        let text = try await messages(system: kCoachingSystemPrompt, user: user)
        return AIResponse(text: text, provenance: provenance)
    }

    func photoCaption(imageJPEG: Data, mode: CaptureMode) async throws -> AIResponse {
        let payload: [String: Any] = [
            "model": modelProvider(),
            "max_tokens": 80,
            "system": "Write a single short, vivid caption (max 14 words). No hashtags.",
            "messages": [
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "image",
                            "source": [
                                "type": "base64",
                                "media_type": "image/jpeg",
                                "data": imageJPEG.base64EncodedString()
                            ]
                        ],
                        [
                            "type": "text",
                            "text": "Caption this \(mode.title) photo."
                        ]
                    ] as [Any]
                ]
            ]
        ]
        let text = try await postMessages(payload: payload)
        return AIResponse(text: text, provenance: provenance)
    }

    private func messages(system: String, user: String) async throws -> String {
        let payload: [String: Any] = [
            "model": modelProvider(),
            "max_tokens": 200,
            "system": system,
            "messages": [["role": "user", "content": user]]
        ]
        return try await postMessages(payload: payload)
    }

    private func postMessages(payload: [String: Any]) async throws -> String {
        guard let key = apiKeyProvider(), !key.isEmpty else {
            throw AIError.invalidAPIKey(provider: "Anthropic")
        }
        guard let url = URL(string: "https://api.anthropic.com/v1/messages") else {
            throw AIError.networkFailure(underlying: "bad URL")
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(key, forHTTPHeaderField: "x-api-key")
        req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        req.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: req)
        } catch {
            throw AIError.networkFailure(underlying: error.localizedDescription)
        }
        try Task.checkCancellation()

        guard let http = response as? HTTPURLResponse else {
            throw AIError.networkFailure(underlying: "no HTTP response")
        }
        switch http.statusCode {
        case 200...299: break
        case 401:       throw AIError.invalidAPIKey(provider: "Anthropic")
        case 429:       throw AIError.rateLimited(provider: "Anthropic")
        default:
            let snippet = String(data: data, encoding: .utf8)?.prefix(160) ?? ""
            throw AIError.networkFailure(underlying: "HTTP \(http.statusCode): \(snippet)")
        }

        guard
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let content = json["content"] as? [[String: Any]],
            let first = content.first,
            let text = first["text"] as? String
        else {
            throw AIError.decoding("missing 'content[0].text'")
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
