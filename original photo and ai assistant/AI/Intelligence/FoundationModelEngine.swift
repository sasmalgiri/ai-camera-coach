//
//  FoundationModelEngine.swift
//  AI Camera Coach — Intelligence layer
//
//  Apple Intelligence on-device LLM via the FoundationModels framework.
//  Available on iOS 26+ devices that have Apple Intelligence enabled.
//

import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

actor FoundationModelEngine: AIEngine {

    init() {}


    let name = "Apple Intelligence"
    let runsOnDevice = true
    let provenance: AIProvenance = .appleIntelligence
    let capabilities: Set<AICapability> = [.coachingAdvice, .scoreExplanation]

    private let systemInstructions = """
    You are a warm, concise photography coach. Speak in plain language.
    Never use technical terms like ISO, EV, aperture, shutter speed,
    histograms, or dynamic range. Give at most three short tips, written
    as imperative sentences (e.g. "Move closer.", "Wait for the smile.").
    Be encouraging.
    """

    func isAvailable() async -> Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) {
            switch SystemLanguageModel.default.availability {
            case .available: return true
            case .unavailable: return false
            }
        } else {
            return false
        }
        #else
        return false
        #endif
    }

    func coachingAdvice(scene: SceneSummary) async throws -> AIResponse {
        let prompt = """
        Here is what the camera sees right now:

        \(scene.promptDescription)

        Write up to three short, friendly tips that will most improve this
        photo. Do not mention scores. Do not use jargon. Maximum 30 words.
        """
        return try await run(prompt: prompt)
    }

    func scoreExplanation(score: PhotoScore, scene: SceneSummary) async throws -> AIResponse {
        let lowest = score.breakdown.min(by: { $0.value < $1.value })?.key ?? "Composition"
        let prompt = """
        The photo's overall score is \(score.total)/100.
        Component scores: \(score.breakdown
            .sorted(by: { $0.key < $1.key })
            .map { "\($0.key) \($0.value)" }
            .joined(separator: ", "))

        Scene snapshot:
        \(scene.promptDescription)

        Briefly explain — in two sentences — why the score is what it is.
        Focus on the weakest area, which is "\(lowest)". End with one
        specific action the user can take to improve.
        """
        return try await run(prompt: prompt)
    }

    // MARK: - Internals

    private func run(prompt: String) async throws -> AIResponse {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) {
            return try await runFoundationModel(prompt: prompt)
        } else {
            throw AIError.unavailable(engine: name,
                                      reason: "Requires iOS 26 or later.")
        }
        #else
        throw AIError.unavailable(engine: name,
                                  reason: "FoundationModels framework not available.")
        #endif
    }

    #if canImport(FoundationModels)
    @available(iOS 26.0, macOS 26.0, *)
    private func runFoundationModel(prompt: String) async throws -> AIResponse {
        // Each call gets a fresh session — we're not maintaining a
        // conversation, and short prompts stay inside the context window.
        let session = LanguageModelSession(instructions: systemInstructions)
        do {
            let response = try await session.respond(to: prompt)
            let text = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else {
                throw AIError.decoding("empty response from Apple Intelligence")
            }
            return AIResponse(text: text, provenance: provenance)
        } catch let error as LanguageModelSession.GenerationError {
            throw mapGenerationError(error)
        } catch {
            throw AIError.networkFailure(underlying: error.localizedDescription)
        }
    }

    @available(iOS 26.0, macOS 26.0, *)
    private func mapGenerationError(_ error: LanguageModelSession.GenerationError) -> AIError {
        switch error {
        case .guardrailViolation:
            return .safetyRefused
        case .rateLimited:
            return .rateLimited(provider: "Apple Intelligence")
        case .unsupportedLanguageOrLocale:
            return .unavailable(engine: name, reason: "Language not supported.")
        case .exceededContextWindowSize:
            return .decoding("prompt too long")
        default:
            return .unavailable(engine: name,
                                reason: error.localizedDescription)
        }
    }
    #endif
}
