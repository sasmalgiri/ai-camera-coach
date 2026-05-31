//
//  SceneSummary.swift
//  AI Camera Coach — Intelligence layer
//
//  A small `Sendable` snapshot of the scene that engines can read without
//  needing CIImage / Vision objects. This is what crosses the actor
//  boundary into the AIRouter.
//

import Foundation

nonisolated struct SceneSummary: Sendable, Hashable {

    enum BrightnessLevel: String, Sendable, Hashable {
        case dark, dim, balanced, bright, harsh
    }

    enum SharpnessLevel: String, Sendable, Hashable {
        case blurry, soft, acceptable, crisp
    }

    enum SubjectPosition: String, Sendable, Hashable {
        case noSubject, center, offCenter, ruleOfThirds
    }

    let mode: CaptureMode
    let faceCount: Int
    let mostEyesOpen: Bool
    let mostSmiling: Bool
    let brightness: BrightnessLevel
    let sharpness: SharpnessLevel
    let subjectPosition: SubjectPosition
    let scoreTotal: Int

    /// Build a SceneSummary from raw analysis values.
    static func make(from analysis: SceneAnalysis,
                     mode: CaptureMode,
                     score: PhotoScore) -> SceneSummary {
        let openCount = analysis.faces.filter { $0.eyesOpenConfidence > 0.55 }.count
        let smileCount = analysis.faces.filter { $0.smileConfidence > 0.5 }.count
        let mostOpen: Bool = {
            guard analysis.faceCount > 0 else { return false }
            return Double(openCount) / Double(analysis.faceCount) >= 0.7
        }()
        let mostSmile: Bool = {
            guard analysis.faceCount > 0 else { return false }
            return Double(smileCount) / Double(analysis.faceCount) >= 0.5
        }()

        let brightness: BrightnessLevel = {
            switch analysis.brightness {
            case ..<0.18: return .dark
            case ..<0.35: return .dim
            case ..<0.70: return .balanced
            case ..<0.88: return .bright
            default:      return .harsh
            }
        }()

        let sharpness: SharpnessLevel = {
            switch analysis.sharpness {
            case ..<0.35: return .blurry
            case ..<0.55: return .soft
            case ..<0.80: return .acceptable
            default:      return .crisp
            }
        }()

        let position: SubjectPosition = {
            guard analysis.faceCount > 0 else { return .noSubject }
            switch analysis.subjectCentered {
            case ..<0.35: return .offCenter
            case ..<0.65: return .center
            default:      return .ruleOfThirds
            }
        }()

        return SceneSummary(
            mode: mode,
            faceCount: analysis.faceCount,
            mostEyesOpen: mostOpen,
            mostSmiling: mostSmile,
            brightness: brightness,
            sharpness: sharpness,
            subjectPosition: position,
            scoreTotal: score.total
        )
    }

    /// Human prose describing the scene — used both for prompting LLMs and
    /// for templated fallbacks.
    var promptDescription: String {
        var parts: [String] = []
        parts.append("Mode: \(mode.title)")
        parts.append("Score: \(scoreTotal)/100")
        parts.append("Faces in frame: \(faceCount)")
        if faceCount > 0 {
            parts.append("Most eyes open: \(mostEyesOpen ? "yes" : "no")")
            parts.append("Most smiling: \(mostSmiling ? "yes" : "no")")
        }
        parts.append("Brightness: \(brightness.rawValue)")
        parts.append("Sharpness: \(sharpness.rawValue)")
        parts.append("Subject placement: \(subjectPosition.rawValue)")
        return parts.joined(separator: "\n")
    }
}
