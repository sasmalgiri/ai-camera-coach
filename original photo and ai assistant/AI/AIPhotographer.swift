//
//  AIPhotographer.swift
//  AI Camera Coach
//

import Foundation

/// Decides when to auto-capture in AI Photographer mode.
@MainActor
final class AIPhotographer {
    private(set) var enabled: Bool = false
    private var lastCaptureAt: Date = .distantPast
    private let cooldown: TimeInterval = 1.8
    private let confidenceThreshold: Double = 0.78

    func enable() {
        enabled = true
        lastCaptureAt = .distantPast
    }

    func disable() {
        enabled = false
    }

    func shouldCapture(score: PhotoScore,
                       analysis: SceneAnalysis,
                       mode: CaptureMode) -> Bool {
        guard enabled else { return false }
        guard Date().timeIntervalSince(lastCaptureAt) > cooldown else { return false }

        var confidence = Double(score.total) / 100.0

        switch mode {
        case .original:
            break // no mode-specific gating in raw mode
        case .family:
            let allOpen = analysis.faces.allSatisfy { $0.eyesOpenConfidence > 0.55 }
            confidence *= (analysis.faceCount > 0 && allOpen) ? 1.0 : 0.55
        case .child:
            confidence *= analysis.sharpness > 0.5 ? 1.0 : 0.55
        case .pet:
            confidence *= (analysis.faceCount > 0 || analysis.sharpness > 0.6) ? 1.0 : 0.6
        case .travel:
            confidence *= analysis.brightness > 0.3 ? 1.0 : 0.7
        case .smart:
            break
        }

        if confidence >= confidenceThreshold {
            lastCaptureAt = Date()
            return true
        }
        return false
    }
}
