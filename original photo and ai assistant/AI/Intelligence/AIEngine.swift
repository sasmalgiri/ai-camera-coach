//
//  AIEngine.swift
//  AI Camera Coach — Intelligence layer
//

import Foundation

/// What an engine claims it can do. Used by the router to skip engines that
/// can't fulfil a request without ever invoking them.
nonisolated enum AICapability: String, Sendable, Hashable {
    case coachingAdvice
    case photoCaption
    case scoreExplanation
    case landmarkRecognition
}

/// Every engine — on-device or cloud — conforms to this. The router only
/// talks to engines through this protocol so they're interchangeable.
nonisolated protocol AIEngine: Sendable {
    var name: String { get }
    var runsOnDevice: Bool { get }
    var provenance: AIProvenance { get }
    var capabilities: Set<AICapability> { get }

    /// Cheap availability check — should not perform a network round-trip.
    func isAvailable() async -> Bool

    func coachingAdvice(scene: SceneSummary) async throws -> AIResponse
    func coachingAdvice(scene: SceneSummary, imageJPEG: Data) async throws -> AIResponse
    func photoCaption(imageJPEG: Data, mode: CaptureMode) async throws -> AIResponse
    func scoreExplanation(score: PhotoScore, scene: SceneSummary) async throws -> AIResponse
    func scoreExplanation(score: PhotoScore,
                          scene: SceneSummary,
                          imageJPEG: Data) async throws -> AIResponse
}

// Default optional implementations.
extension AIEngine {
    func photoCaption(imageJPEG: Data, mode: CaptureMode) async throws -> AIResponse {
        throw AIError.unsupported(capability: .photoCaption, engine: name)
    }

    func scoreExplanation(score: PhotoScore, scene: SceneSummary) async throws -> AIResponse {
        throw AIError.unsupported(capability: .scoreExplanation, engine: name)
    }

    /// Default: ignore the image and fall back to text-only coaching.
    func coachingAdvice(scene: SceneSummary, imageJPEG: Data) async throws -> AIResponse {
        try await coachingAdvice(scene: scene)
    }

    /// Default: ignore the image and fall back to text-only explanation.
    func scoreExplanation(score: PhotoScore,
                          scene: SceneSummary,
                          imageJPEG: Data) async throws -> AIResponse {
        try await scoreExplanation(score: score, scene: scene)
    }
}
