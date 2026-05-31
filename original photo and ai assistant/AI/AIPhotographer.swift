//
//  AIPhotographer.swift
//  AI Camera Coach
//

import Foundation

@MainActor
final class AIPhotographer {
    private(set) var enabled: Bool = false
    private var lastCaptureAt: Date = .distantPast
    private let cooldown: TimeInterval = 1.8
    private let confidenceThreshold: Double = 0.78

    /// Human-readable explanation of the most recent decision. Empty when
    /// disabled. The UI surfaces this from the AI Expert sheet so the
    /// user can see *why* the auto-capture didn't fire.
    private(set) var lastDecisionReason: String = ""

    func enable() {
        enabled = true
        lastCaptureAt = .distantPast
        lastDecisionReason = "Ready — waiting for a confident moment."
    }

    func disable() {
        enabled = false
        lastDecisionReason = ""
    }

    func shouldCapture(score: PhotoScore,
                       analysis: SceneAnalysis,
                       mode: CaptureMode) -> Bool {
        guard enabled else { return false }
        guard Date().timeIntervalSince(lastCaptureAt) > cooldown else {
            lastDecisionReason = "Cooling down after the last shot."
            return false
        }

        var confidence = Double(score.total) / 100.0
        var blockers: [String] = []

        switch mode {
        case .family:
            let allOpen = analysis.faces.allSatisfy { $0.eyesOpenConfidence > 0.55 }
            if !(analysis.faceCount > 0 && allOpen) {
                confidence *= 0.55
                blockers.append("waiting for everyone's eyes to open")
            }
        case .child:
            if analysis.sharpness <= 0.5 {
                confidence *= 0.55
                blockers.append("waiting for sharper focus")
            }
        case .pet:
            if !(analysis.faceCount > 0 || analysis.sharpness > 0.6) {
                confidence *= 0.6
                blockers.append("looking for a clear pet face or sharper focus")
            }
        case .travel:
            if analysis.brightness <= 0.3 {
                confidence *= 0.7
                blockers.append("light is a little dim")
            }
        case .smart, .original:
            if score.total < 60 { blockers.append("score is still climbing") }
        }

        if confidence >= confidenceThreshold {
            lastCaptureAt = Date()
            lastDecisionReason = "Captured — confident moment (\(Int(confidence * 100))/100)."
            return true
        }

        if blockers.isEmpty {
            lastDecisionReason = "Confidence is \(Int(confidence * 100))/100 — close, but not quite."
        } else {
            lastDecisionReason = "Holding — " + blockers.joined(separator: ", ") + "."
        }
        return false
    }
}
