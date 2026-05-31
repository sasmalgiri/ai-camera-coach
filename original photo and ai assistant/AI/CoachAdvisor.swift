//
//  CoachAdvisor.swift
//  AI Camera Coach
//

import CoreGraphics
import Foundation

final class CoachAdvisor: Sendable {

    func suggestions(for analysis: SceneAnalysis, mode: CaptureMode) -> [CoachSuggestion] {
        var out: [CoachSuggestion] = []

        if analysis.brightness < 0.25 {
            out.append(.init(icon: "sun.max",
                             message: "Turn toward more light",
                             priority: .important))
        } else if analysis.brightness > 0.85 {
            out.append(.init(icon: "sun.haze",
                             message: "Shade your subject — it's a bit bright",
                             priority: .suggestion))
        }

        if let face = analysis.faces.first {
            if face.boundingBox.width < 0.18 {
                out.append(.init(icon: "arrow.down.right.and.arrow.up.left",
                                 message: "Move a little closer",
                                 priority: .suggestion))
            } else if face.boundingBox.width > 0.7 {
                out.append(.init(icon: "arrow.up.left.and.arrow.down.right",
                                 message: "Step back a little",
                                 priority: .suggestion))
            }
        }

        if analysis.subjectCentered < 0.4 && analysis.faceCount > 0 {
            out.append(.init(icon: "rectangle.dashed",
                             message: "Place your subject off-center for stronger framing",
                             priority: .info))
        }

        if analysis.faceCount == 0 && mode != .travel {
            out.append(.init(icon: "viewfinder",
                             message: "Frame your subject in view",
                             priority: .info))
        }

        switch mode {
        case .family:
            if analysis.faceCount > 1 {
                let openCount = analysis.faces.filter { $0.eyesOpenConfidence > 0.55 }.count
                let ratio = Double(openCount) / Double(analysis.faceCount)
                if ratio < 0.7 {
                    out.append(.init(icon: "eye",
                                     message: "Wait — not everyone's eyes are open",
                                     priority: .important))
                }
            }
        case .child:
            out.append(.init(icon: "hand.raised",
                             message: "Hold steady — auto-capture is watching",
                             priority: .info))
        case .pet:
            out.append(.init(icon: "pawprint",
                             message: "Get to your pet's eye level",
                             priority: .info))
        case .travel:
            out.append(.init(icon: "level",
                             message: "Keep the horizon level",
                             priority: .info))
        case .smart:
            break
        }

        if out.isEmpty {
            out.append(.init(icon: "checkmark.seal",
                             message: "Looks great — tap to capture",
                             priority: .info))
        }
        return out.sorted { $0.priority > $1.priority }
    }
}
