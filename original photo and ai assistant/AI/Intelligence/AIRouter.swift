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
//         a. MoEEngine (parallel Apple experts + parallel Apple brain)
//             ── only when a JPEG of the live frame is available
//         b. FoundationModelEngine (Apple Intelligence, text-only)
//         c. User's preferred cloud provider (if cloudCallsAllowed)
//         d. NaturalLanguageEngine (always-on templated fallback)
//

import Foundation

actor AIRouter {

    private let moe: MoEEngine
    private let foundation: FoundationModelEngine
    private let fallback: NaturalLanguageEngine
    private let openAI: OpenAICloudEngine
    private let anthropic: AnthropicCloudEngine
    private let settings: AISettingsSnapshot

    init(settings: AISettingsSnapshot) {
        self.settings = settings
        self.moe = MoEEngine()
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

    func coachingAdvice(scene: SceneSummary,
                        imageJPEG: Data?,
                        onPartial: (@Sendable (String) async -> Void)? = nil) async -> AIResponse {
        await runChain(imageJPEG: imageJPEG, onPartial: onPartial) { engine, image, partial in
            if let moe = engine as? MoEEngine, let image {
                await moe.setOnPartial(partial)
                return try await moe.coachingAdvice(scene: scene, imageJPEG: image)
            }
            if let image {
                return try await engine.coachingAdvice(scene: scene, imageJPEG: image)
            }
            return try await engine.coachingAdvice(scene: scene)
        }
    }

    func scoreExplanation(score: PhotoScore,
                          scene: SceneSummary,
                          imageJPEG: Data?,
                          onPartial: (@Sendable (String) async -> Void)? = nil) async -> AIResponse {
        await runChain(imageJPEG: imageJPEG, onPartial: onPartial) { engine, image, partial in
            if let moe = engine as? MoEEngine, let image {
                await moe.setOnPartial(partial)
                return try await moe.scoreExplanation(score: score,
                                                      scene: scene,
                                                      imageJPEG: image)
            }
            if let image {
                return try await engine.scoreExplanation(score: score,
                                                         scene: scene,
                                                         imageJPEG: image)
            }
            return try await engine.scoreExplanation(score: score, scene: scene)
        }
    }

    func photoCaption(imageJPEG: Data, mode: CaptureMode) async -> AIResponse {
        if !settings.cloudCallsAllowed {
            return AIResponse(
                text: "A \(mode.title) photo from your camera.",
                provenance: .naturalLanguageFallback
            )
        }
        for engine in orderedCloudEngines(requiring: .photoCaption) {
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

    private func runChain(
        imageJPEG: Data?,
        onPartial: (@Sendable (String) async -> Void)?,
        _ work: @Sendable (AIEngine, Data?, (@Sendable (String) async -> Void)?) async throws -> AIResponse
    ) async -> AIResponse {
        for engine in await orderedEngines(hasImage: imageJPEG != nil) {
            guard await engine.isAvailable() else { continue }
            do {
                try Task.checkCancellation()
                return try await work(engine, imageJPEG, onPartial)
            } catch is CancellationError {
                break
            } catch let error as AIError where !error.isRecoverable {
                return AIResponse(
                    text: error.errorDescription ?? "The AI couldn't help with that.",
                    provenance: .naturalLanguageFallback
                )
            } catch {
                continue
            }
        }
        return AIResponse(text: "Tap the shutter when the moment feels right.",
                          provenance: .naturalLanguageFallback)
    }

    private func orderedEngines(hasImage: Bool) async -> [AIEngine] {
        var list: [AIEngine] = []

        // 1) MoE only useful if we have a frame to feed the experts.
        if hasImage { list.append(moe) }

        // 2) Plain Apple Intelligence (text-only).
        list.append(foundation)

        // 3) Cloud engines only if allowed.
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

        // 4) Templated fallback last — guaranteed to return something.
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
