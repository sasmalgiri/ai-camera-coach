//
//  PhotoScorer.swift
//  AI Camera Coach
//

import Foundation

final class PhotoScorer: Sendable {
    func score(_ analysis: SceneAnalysis, mode: CaptureMode) -> PhotoScore {
        var components: [String: Int] = [:]

        // Exposure — peak around 0.55, drops off symmetrically.
        let exposureDelta = abs(analysis.brightness - 0.55)
        let exposure = Int(max(0.0, 1.0 - exposureDelta * 2.2) * 100)
        components["Exposure"] = exposure

        // Sharpness
        components["Sharpness"] = Int(analysis.sharpness * 100)

        // Composition
        var composition = Int(analysis.subjectCentered * 100)
        if analysis.faceCount == 0 && mode == .travel { composition = max(composition, 65) }
        components["Composition"] = composition

        // Faces
        var faces = 75
        if !analysis.faces.isEmpty {
            let avgEyes = analysis.faces.map(\.eyesOpenConfidence).reduce(0, +)
                / Double(analysis.faces.count)
            let avgSmile = analysis.faces.map(\.smileConfidence).reduce(0, +)
                / Double(analysis.faces.count)
            faces = Int((avgEyes * 0.7 + avgSmile * 0.3) * 100)
        }
        components["Faces"] = faces

        let weights = weights(for: mode)
        var weighted = 0.0
        var total = 0.0
        for (key, weight) in weights {
            weighted += Double(components[key] ?? 0) * weight
            total += weight
        }
        let final = Int(weighted / max(total, 0.0001))
        return PhotoScore(total: min(100, max(0, final)), breakdown: components)
    }

    private func weights(for mode: CaptureMode) -> [String: Double] {
        switch mode {
        case .smart:  return ["Exposure": 1.0, "Sharpness": 1.0, "Composition": 1.0, "Faces": 0.8]
        case .family: return ["Exposure": 1.0, "Sharpness": 1.2, "Composition": 0.7, "Faces": 2.0]
        case .child:  return ["Exposure": 0.7, "Sharpness": 1.5, "Composition": 0.7, "Faces": 1.5]
        case .pet:    return ["Exposure": 0.8, "Sharpness": 1.5, "Composition": 0.8, "Faces": 1.2]
        case .travel: return ["Exposure": 1.2, "Sharpness": 1.0, "Composition": 1.5, "Faces": 0.4]
        }
    }
}
