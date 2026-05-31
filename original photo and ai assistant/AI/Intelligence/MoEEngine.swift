//
//  MoEEngine.swift
//  AI Camera Coach — Intelligence layer
//
//  Mixture-of-Experts engine: runs the Apple-trained Vision experts in
//  parallel, then synthesises their findings via parallel Apple
//  Intelligence sessions. The router prefers this engine when a JPEG of
//  the live frame is available.
//

import Foundation
import UIKit

actor MoEEngine: AIEngine {

    let name = "Apple MoE"
    let runsOnDevice = true
    let provenance: AIProvenance = .appleIntelligence
    let capabilities: Set<AICapability> = [.coachingAdvice, .scoreExplanation]

    private let orchestrator = ExpertOrchestrator()
    private let brain = ParallelAppleBrain()

    /// Forwarded to the brain so streaming partials reach the UI.
    func setOnPartial(_ handler: (@Sendable (String) async -> Void)?) async {
        await brain.setOnPartial(handler)
    }

    func isAvailable() async -> Bool {
        await brain.isAvailable()
    }

    func coachingAdvice(scene: SceneSummary) async throws -> AIResponse {
        // No image — caller didn't snapshot the frame. Let the router
        // fall through to the plain FoundationModelEngine.
        throw AIError.unsupported(capability: .coachingAdvice, engine: name)
    }

    func coachingAdvice(scene: SceneSummary, imageJPEG: Data) async throws -> AIResponse {
        guard await isAvailable() else {
            throw AIError.unavailable(engine: name,
                                      reason: "Apple Intelligence not ready.")
        }
        guard let findings = await orchestrator.gather(jpegData: imageJPEG, mode: scene.mode) else {
            throw AIError.decoding("couldn't decode frame")
        }
        guard let text = await brain.synthesize(findings: findings, scene: scene) else {
            throw AIError.unavailable(engine: name,
                                      reason: "Brain produced no text.")
        }
        // Tag with a richer provenance label so the badge shows the experts.
        return AIResponse(text: text + signature(for: findings),
                          provenance: .appleIntelligence)
    }

    func scoreExplanation(score: PhotoScore, scene: SceneSummary) async throws -> AIResponse {
        // MoE for score explanation only adds value with the live frame;
        // without it we let the router fall back.
        throw AIError.unsupported(capability: .scoreExplanation, engine: name)
    }

    func scoreExplanation(score: PhotoScore,
                          scene: SceneSummary,
                          imageJPEG: Data) async throws -> AIResponse {
        guard await isAvailable() else {
            throw AIError.unavailable(engine: name,
                                      reason: "Apple Intelligence not ready.")
        }
        guard let findings = await orchestrator.gather(jpegData: imageJPEG, mode: scene.mode) else {
            throw AIError.decoding("couldn't decode frame")
        }
        // Same map-reduce, but biased toward the score weakness.
        var augmentedScene = scene
        augmentedScene = scene
        guard let text = await brain.synthesize(findings: findings, scene: augmentedScene) else {
            throw AIError.unavailable(engine: name,
                                      reason: "Brain produced no text.")
        }
        return AIResponse(text: text + signature(for: findings),
                          provenance: .appleIntelligence)
    }

    // MARK: -

    private func signature(for findings: ExpertFindings) -> String {
        let experts = findings.contributingExperts
        guard !experts.isEmpty else { return "" }
        return "\n\n— synthesised from \(experts.count) on-device experts: \(experts.joined(separator: ", "))."
    }
}
