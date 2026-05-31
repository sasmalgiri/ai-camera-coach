//
//  SceneAnalysis.swift
//  AI Camera Coach
//

import CoreGraphics
import Foundation

nonisolated struct SceneAnalysis: Equatable, Sendable {
    var faceCount: Int = 0
    var faces: [FaceObservation] = []
    var brightness: Double = 0.5       // 0 = dark, 1 = bright
    var sharpness: Double = 0.5        // 0 = blurry, 1 = crisp
    var horizonTilt: Double = 0        // degrees off level
    var subjectCentered: Double = 0.5  // 0 = poorly placed, 1 = well placed
    var motionLevel: Double = 0        // 0 = still, 1 = motion

    nonisolated struct FaceObservation: Equatable, Sendable {
        let boundingBox: CGRect        // Vision-normalized 0..1
        let eyesOpenConfidence: Double
        let smileConfidence: Double
    }
}
