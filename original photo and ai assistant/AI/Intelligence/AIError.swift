//
//  AIError.swift
//  AI Camera Coach — Intelligence layer
//

import Foundation

nonisolated enum AIError: LocalizedError, Sendable {
    case unsupported(capability: AICapability, engine: String)
    case unavailable(engine: String, reason: String)
    case forensicModeBlocked
    case noEngineAvailable
    case invalidAPIKey(provider: String)
    case rateLimited(provider: String)
    case networkFailure(underlying: String)
    case safetyRefused
    case cancelled
    case decoding(String)

    var errorDescription: String? {
        switch self {
        case .unsupported(let cap, let engine):
            return "\(engine) doesn't support \(cap.rawValue)."
        case .unavailable(let engine, let reason):
            return "\(engine) is not available: \(reason)"
        case .forensicModeBlocked:
            return "Cloud AI is disabled in Forensic Mode. On-device only."
        case .noEngineAvailable:
            return "No AI engine is available right now."
        case .invalidAPIKey(let provider):
            return "Your \(provider) API key was rejected. Update it in Settings."
        case .rateLimited(let provider):
            return "\(provider) is rate-limited. Try again in a moment."
        case .networkFailure(let underlying):
            return "Network problem: \(underlying)"
        case .safetyRefused:
            return "The AI declined to process this. Try again with a different scene."
        case .cancelled:
            return "Request was cancelled."
        case .decoding(let detail):
            return "Couldn't read the AI response (\(detail))."
        }
    }

    /// Whether the router should try the next engine in the fallback chain
    /// instead of bubbling this error to the UI.
    var isRecoverable: Bool {
        switch self {
        case .unsupported, .unavailable, .invalidAPIKey,
             .networkFailure, .rateLimited:
            return true
        case .forensicModeBlocked, .safetyRefused, .cancelled,
             .noEngineAvailable, .decoding:
            return false
        }
    }
}
