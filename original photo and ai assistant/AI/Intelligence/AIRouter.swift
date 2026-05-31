//
//  AIRouter.swift
//  AI Camera Coach — Intelligence layer
//
//  The single place that decides which engine answers a request.
//  Privacy enforcement (kill switch) lives here.
//
//  Decision policy:
//    1. If forensicMode → cloud engines are NEVER tried.
//    2. Otherwise, try engines in order:
//         a. FoundationModelEngine (Apple Intelligence, on-device)
//         b. User's preferred cloud provider (if cloudCallsAllowed)
//         c. NaturalLanguageEngine (always-on templated fallback)
//

import Foundation

actor AIRouter {

    private let foundation: FoundationModelEngine
    private let fallback: NaturalLanguageEngine
    private let openAI: OpenAICloudEngine
    private let anthropic: AnthropicCloudEngine
    private let settings: AISettingsSnapshot

    /// `AISettingsSnapshot` is an immutable view of `AISettingsStore` that
    /// we capture each time we build a router. We rebuild the router on
    /// settings changes — simpler than threading bindings through actors.
    init(settings: AISettingsSnapshot) {
        self.settings = settings
        self.foundation = FoundationModelEngine()
        self.fallback = NaturalLanguageEngine()

        let openAIKey = settings.openAIKey
        let openAIModel = settings.openAIModel
        self.openAI = OpenAICloudEngine(
            apiKeyProvider: { openAIKey },
            modelProvider: { openAIModel }
        )
        let anthropicKey = settings.anthropicKey
        let anthropicModel = settings.anthropicModel
        self.anthropic = AnthropicCloudEngine(
            apiKeyProvider: { anthropicKey },
            modelProvider: { anthropicModel }
        )
    }

    // MARK: - Public surface

    func coachingAdvice(scene: SceneSummary) async -> AIResponse {
        await runChain { engine in
            try await engine.coachingAdvice(scene: scene)
        }
    }

    func scoreExplanation(score: PhotoScore, scene: SceneSummary) async -> AIResponse {
        await runChain { engine in
            try await engine.scoreExplanation(score: score, scene: scene)
        }
    }

    func photoCaption(imageJPEG: Data, mode: CaptureMode) async -> AIResponse {
        // Captioning needs vision — only cloud engines support it today.
        // If forensic mode or cloud disabled, we degrade gracefully.
        if !settings.cloudCallsAllowed {
            return AIResponse(
                text: "A \(mode.title) photo from your camera.",
                provenance: .naturalLanguageFallback
            )
        }
        let engines = orderedCloudEngines(requiring: .photoCaption)
        for engine in engines {
            guard await engine.isAvailable() else { continue }
            do {
                return try await engine.photoCaption(imageJPEG: imageJPEG, mode: mode)
            } catch let error as AIError where error.isRecoverable {
                continue
            } catch {
                continue
            }
        }
        return AIResponse(
            text: "A \(mode.title) photo from your camera.",
            provenance: .naturalLanguageFallback
        )
    }

    // MARK: - Chain

    private func runChain(_ work: @Sendable (AIEngine) async throws -> AIResponse) async -> AIResponse {
        for engine in await orderedEngines() {
            guard await engine.isAvailable() else { continue }
            do {
                try Task.checkCancellation()
                return try await work(engine)
            } catch is CancellationError {
                break
            } catch let error as AIError where !error.isRecoverable {
                // Hard failure (safety refusal, etc.) — don't try other
                // engines. Return a friendly message tagged on-device.
                return AIResponse(
                    text: error.errorDescription ?? "The AI couldn't help with that.",
                    provenance: .naturalLanguageFallback
                )
            } catch {
                continue
            }
        }
        // Final safety net — should be unreachable because fallback is
        // always available.
        return AIResponse(text: "Tap the shutter when the moment feels right.",
                          provenance: .naturalLanguageFallback)
    }

    /// Build the ordered engine list honouring forensic mode.
    private func orderedEngines() async -> [AIEngine] {
        var list: [AIEngine] = []

        // 1) On-device LLM first.
        list.append(foundation)

        // 2) Cloud engines only if allowed.
        if settings.cloudCallsAllowed {
            switch settings.preferredProvider {
            case .openAI:
                list.append(openAI)
                list.append(anthropic)
            case .anthropic:
                list.append(anthropic)
                list.append(openAI)
            }
        }

        // 3) Templated fallback last — guaranteed to return something.
        list.append(fallback)
        return list
    }

    private func orderedCloudEngines(requiring capability: AICapability) -> [AIEngine] {
        guard settings.cloudCallsAllowed else { return [] }
        var list: [AIEngine] = []
        switch settings.preferredProvider {
        case .openAI:
            list = [openAI, anthropic]
        case .anthropic:
            list = [anthropic, openAI]
        }
        return list.filter { $0.capabilities.contains(capability) }
    }
}

// MARK: - Snapshot type

/// Immutable snapshot of settings used by the router. Settings store is
/// MainActor but routers are actor-isolated — we cross that boundary
/// with a Sendable copy.
nonisolated struct AISettingsSnapshot: Sendable {
    let cloudAIEnabled: Bool
    let forensicMode: Bool
    let hasConsentedToCloud: Bool
    let preferredProvider: AISettingsStore.CloudProviderChoice
    let openAIKey: String
    let anthropicKey: String
    let openAIModel: String
    let anthropicModel: String

    var cloudCallsAllowed: Bool {
        cloudAIEnabled && !forensicMode && hasConsentedToCloud
    }

    @MainActor
    init(_ s: AISettingsStore) {
        self.cloudAIEnabled = s.cloudAIEnabled
        self.forensicMode = s.forensicMode
        self.hasConsentedToCloud = s.hasConsentedToCloud
        self.preferredProvider = s.preferredProvider
        self.openAIKey = s.openAIKey
        self.anthropicKey = s.anthropicKey
        self.openAIModel = s.openAIModel
        self.anthropicModel = s.anthropicModel
    }
}
