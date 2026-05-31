//
//  SceneAnalyzer.swift
//  AI Camera Coach
//

import CoreGraphics
import CoreImage
import UIKit
import Vision

/// Lightweight on-device scene analysis using Vision.
/// All work is performed off the main actor.
final class SceneAnalyzer: Sendable {

    private let ciContext: CIContext

    init() {
        self.ciContext = CIContext(options: [.useSoftwareRenderer: false])
    }

    func analyze(_ image: CIImage) async -> SceneAnalysis {
        var result = SceneAnalysis()
        result.brightness = brightness(of: image)
        result.sharpness = sharpness(of: image)
        result.faces = await detectFaces(in: image)
        result.faceCount = result.faces.count
        result.subjectCentered = subjectCentering(faces: result.faces)
        return result
    }

    // MARK: - Face Detection

    private func detectFaces(in image: CIImage) async -> [SceneAnalysis.FaceObservation] {
        await withCheckedContinuation { (cont: CheckedContinuation<[SceneAnalysis.FaceObservation], Never>) in
            let request = VNDetectFaceLandmarksRequest { req, _ in
                guard let results = req.results as? [VNFaceObservation] else {
                    cont.resume(returning: [])
                    return
                }
                let mapped: [SceneAnalysis.FaceObservation] = results.map { obs in
                    let eyes = self.eyesOpenScore(obs)
                    let smile = self.smileScore(obs)
                    return SceneAnalysis.FaceObservation(
                        boundingBox: obs.boundingBox,
                        eyesOpenConfidence: eyes,
                        smileConfidence: smile
                    )
                }
                cont.resume(returning: mapped)
            }
            let handler = VNImageRequestHandler(ciImage: image, orientation: .up, options: [:])
            do {
                try handler.perform([request])
            } catch {
                cont.resume(returning: [])
            }
        }
    }

    private func eyesOpenScore(_ obs: VNFaceObservation) -> Double {
        guard let left = obs.landmarks?.leftEye,
              let right = obs.landmarks?.rightEye else {
            return 0.6
        }
        return (aperture(of: left) + aperture(of: right)) / 2.0
    }

    private func smileScore(_ obs: VNFaceObservation) -> Double {
        guard let mouth = obs.landmarks?.outerLips else { return 0.5 }
        return aperture(of: mouth, scale: 6.0)
    }

    private func aperture(of region: VNFaceLandmarkRegion2D, scale: Double = 9.0) -> Double {
        let points = region.normalizedPoints
        guard let yMin = points.map({ Double($0.y) }).min(),
              let yMax = points.map({ Double($0.y) }).max() else { return 0.5 }
        return min(1.0, max(0.0, (yMax - yMin) * scale))
    }

    // MARK: - Brightness & Sharpness

    private func brightness(of image: CIImage) -> Double {
        let extent = image.extent
        guard extent.width > 0, extent.height > 0 else { return 0.5 }
        let filter = CIFilter(name: "CIAreaAverage", parameters: [
            kCIInputImageKey: image,
            kCIInputExtentKey: CIVector(cgRect: extent)
        ])
        guard let output = filter?.outputImage else { return 0.5 }
        var pixel = [UInt8](repeating: 0, count: 4)
        ciContext.render(output,
                         toBitmap: &pixel,
                         rowBytes: 4,
                         bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                         format: .RGBA8,
                         colorSpace: CGColorSpaceCreateDeviceRGB())
        let r = Double(pixel[0]) / 255.0
        let g = Double(pixel[1]) / 255.0
        let b = Double(pixel[2]) / 255.0
        return 0.299 * r + 0.587 * g + 0.114 * b
    }

    private func sharpness(of image: CIImage) -> Double {
        // Heuristic: compare brightness variance via small downsample.
        // Returns a value in 0..1 weighted toward "acceptable".
        let extent = image.extent
        guard extent.width > 0 else { return 0.6 }
        // Apply a Laplacian-like high-pass and read average magnitude.
        let filter = CIFilter(name: "CIConvolution3X3", parameters: [
            kCIInputImageKey: image,
            "inputWeights": CIVector(values: [0, -1, 0, -1, 4, -1, 0, -1, 0], count: 9)
        ])
        guard let edges = filter?.outputImage else { return 0.6 }
        let average = CIFilter(name: "CIAreaAverage", parameters: [
            kCIInputImageKey: edges,
            kCIInputExtentKey: CIVector(cgRect: extent)
        ])
        guard let out = average?.outputImage else { return 0.6 }
        var pixel = [UInt8](repeating: 0, count: 4)
        ciContext.render(out,
                         toBitmap: &pixel,
                         rowBytes: 4,
                         bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                         format: .RGBA8,
                         colorSpace: CGColorSpaceCreateDeviceRGB())
        let magnitude = (Double(pixel[0]) + Double(pixel[1]) + Double(pixel[2])) / (3.0 * 255.0)
        // Scale and clamp.
        return min(1.0, max(0.0, magnitude * 6.0 + 0.35))
    }

    // MARK: - Composition

    private func subjectCentering(faces: [SceneAnalysis.FaceObservation]) -> Double {
        guard let largest = faces.max(by: { area($0.boundingBox) < area($1.boundingBox) }) else {
            return 0.6
        }
        let cx = largest.boundingBox.midX
        // Reward x near the rule-of-thirds verticals (0.33 or 0.66).
        let xDelta = min(abs(cx - 0.33), abs(cx - 0.66))
        let centering = max(0.0, 1.0 - Double(xDelta) * 2.5)
        return centering
    }

    private func area(_ rect: CGRect) -> CGFloat {
        rect.width * rect.height
    }
}
