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
///
/// `Sendable` because engines are passed across actor boundaries.
nonisolated protocol AIEngine: Sendable {
    var name: String { get }
    var runsOnDevice: Bool { get }
    var provenance: AIProvenance { get }
    var capabilities: Set<AICapability> { get }

    /// Cheap availability check — should not perform a network round-trip.
    /// Cloud engines return false when no key is configured; on-device
    /// engines return false on unsupported OS versions.
    func isAvailable() async -> Bool

    func coachingAdvice(scene: SceneSummary) async throws -> AIResponse
    func photoCaption(imageJPEG: Data, mode: CaptureMode) async throws -> AIResponse
    func scoreExplanation(score: PhotoScore, scene: SceneSummary) async throws -> AIResponse
}

// Default optional implementations so individual engines only override what
// they support. Anything not supported throws `.unsupported`.
extension AIEngine {
    func photoCaption(imageJPEG: Data, mode: CaptureMode) async throws -> AIResponse {
        throw AIError.unsupported(capability: .photoCaption, engine: name)
    }

    func scoreExplanation(score: PhotoScore, scene: SceneSummary) async throws -> AIResponse {
        throw AIError.unsupported(capability: .scoreExplanation, engine: name)
    }
}
