//
//  NaturalLanguageEngine.swift
//  AI Camera Coach — Intelligence layer
//
//  Pure-on-device fallback. No generative model — uses NaturalLanguage
//  framework lightly and high-quality templated prose so the user always
//  gets a useful tip, even on devices without Apple Intelligence.
//

import Foundation
import NaturalLanguage

actor NaturalLanguageEngine: AIEngine {

    init() {}


    let name = "On-Device Fallback"
    let runsOnDevice = true
    let provenance: AIProvenance = .naturalLanguageFallback
    let capabilities: Set<AICapability> = [.coachingAdvice, .scoreExplanation]

    func isAvailable() async -> Bool { true }

    // MARK: - Coaching

    func coachingAdvice(scene: SceneSummary) async throws -> AIResponse {
        let tips = composeTips(for: scene)
        let body = tips.prefix(3).joined(separator: " ")
        return AIResponse(text: body, provenance: provenance)
    }

    func scoreExplanation(score: PhotoScore, scene: SceneSummary) async throws -> AIResponse {
        let weakest = score.breakdown.min(by: { $0.value < $1.value })
        let strongest = score.breakdown.max(by: { $0.value < $1.value })

        var lines: [String] = []
        lines.append("Your photo is at \(score.total) out of 100.")
        if let strongest, strongest.value >= 60 {
            lines.append("\(strongest.key) is your strongest area.")
        }
        if let weakest, weakest.value < 60 {
            lines.append(actionFor(weakest: weakest.key, scene: scene))
        } else {
            lines.append("Tap the shutter when the moment looks right.")
        }
        let text = lines.joined(separator: " ")
        return AIResponse(text: text, provenance: provenance)
    }

    // MARK: - Templates

    private func composeTips(for s: SceneSummary) -> [String] {
        var tips: [String] = []

        switch s.brightness {
        case .dark:     tips.append("It's a bit dark — turn toward more light.")
        case .dim:      tips.append("Step toward a window or brighter spot.")
        case .balanced: break
        case .bright:   tips.append("Lovely light — keep the sun behind you.")
        case .harsh:    tips.append("Shade your subject to soften the light.")
        }

        switch s.sharpness {
        case .blurry, .soft:
            tips.append("Hold the phone with both hands and pause a beat.")
        case .acceptable, .crisp:
            break
        }

        if s.faceCount > 0 {
            if !s.mostEyesOpen {
                tips.append("Wait a moment for everyone's eyes to open.")
            }
            switch s.subjectPosition {
            case .offCenter:
                tips.append("Slide your subject toward the middle or a third line.")
            case .center:
                tips.append("Try placing your subject a third from the edge for a stronger photo.")
            case .ruleOfThirds, .noSubject:
                break
            }
        } else if s.mode != .travel {
            tips.append("Frame your subject in view.")
        }

        switch s.mode {
        case .family where s.faceCount > 1 && !s.mostSmiling:
            tips.append("Try a quick joke — everyone responds to a real laugh.")
        case .child:
            tips.append("Anticipate — kids move, so press just before the moment.")
        case .pet:
            tips.append("Get down to your pet's eye level.")
        case .travel:
            tips.append("Keep the horizon level and leave a little breathing room.")
        default:
            break
        }

        if tips.isEmpty {
            tips.append("Looks great — tap when you're ready.")
        }
        return tips
    }

    private func actionFor(weakest: String, scene: SceneSummary) -> String {
        switch weakest {
        case "Exposure":
            return scene.brightness == .dark
                ? "Move toward better light to lift exposure."
                : "Tap the screen on your subject to balance exposure."
        case "Sharpness":
            return "Steady the phone and pause briefly before pressing the shutter."
        case "Composition":
            return "Place your subject along a third line instead of dead center."
        case "Faces":
            return "Wait for open eyes and a relaxed expression."
        default:
            return "Try a small adjustment in framing or angle."
        }
    }
}
