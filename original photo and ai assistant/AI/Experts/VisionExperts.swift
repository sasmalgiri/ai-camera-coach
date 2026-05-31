//
//  VisionExperts.swift
//  AI Camera Coach — MoE layer
//
//  Apple-trained on-device specialists. Each function performs a single
//  Vision request and returns a typed finding. Designed to be called
//  in parallel by ExpertOrchestrator (Vision requests are CPU-bound, so
//  TaskGroup actually parallelises them across cores).
//

import CoreGraphics
import CoreImage
import Foundation
import Vision

nonisolated enum VisionExperts {

    // MARK: - Face

    static func face(in image: CIImage) async -> FaceFinding? {
        let request = VNDetectFaceLandmarksRequest()
        guard performSafely(request, on: image) else { return nil }

        let observations = request.results ?? []
        guard !observations.isEmpty else {
            return FaceFinding(count: 0, mostEyesOpen: false,
                               mostSmiling: false, primaryBoundingBox: nil)
        }
        let primary = observations.max {
            $0.boundingBox.width * $0.boundingBox.height
                < $1.boundingBox.width * $1.boundingBox.height
        }
        let openCount = observations.filter { eyesOpen($0) > 0.55 }.count
        let smileCount = observations.filter { smile($0) > 0.5 }.count
        return FaceFinding(
            count: observations.count,
            mostEyesOpen: Double(openCount) / Double(observations.count) >= 0.7,
            mostSmiling: Double(smileCount) / Double(observations.count) >= 0.5,
            primaryBoundingBox: primary?.boundingBox
        )
    }

    private static func eyesOpen(_ obs: VNFaceObservation) -> Double {
        guard let left = obs.landmarks?.leftEye,
              let right = obs.landmarks?.rightEye else { return 0.6 }
        return (aperture(left) + aperture(right)) / 2
    }

    private static func smile(_ obs: VNFaceObservation) -> Double {
        guard let lips = obs.landmarks?.outerLips else { return 0.5 }
        return aperture(lips, scale: 6)
    }

    private static func aperture(_ region: VNFaceLandmarkRegion2D, scale: Double = 9) -> Double {
        let points = region.normalizedPoints
        guard let yMin = points.map({ Double($0.y) }).min(),
              let yMax = points.map({ Double($0.y) }).max() else { return 0.5 }
        return min(1, max(0, (yMax - yMin) * scale))
    }

    // MARK: - OCR

    static func ocr(in image: CIImage) async -> OCRFinding? {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        guard performSafely(request, on: image) else {
            return OCRFinding(snippets: [])
        }
        let observations = request.results ?? []
        let snippets = observations
            .compactMap { $0.topCandidates(1).first?.string }
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        return OCRFinding(snippets: snippets)
    }

    // MARK: - Classification

    static func classification(in image: CIImage) async -> ClassificationFinding? {
        let request = VNClassifyImageRequest()
        guard performSafely(request, on: image) else {
            return ClassificationFinding(labels: [])
        }
        let observations = request.results ?? []
        let top = observations
            .filter { $0.confidence >= 0.2 }
            .sorted { $0.confidence > $1.confidence }
            .prefix(8)
            .map { $0.identifier }
        return ClassificationFinding(labels: Array(top))
    }

    // MARK: - Horizon

    static func horizon(in image: CIImage) async -> HorizonFinding? {
        let request = VNDetectHorizonRequest()
        guard performSafely(request, on: image) else {
            return HorizonFinding(tiltDegrees: 0)
        }
        guard let obs = request.results?.first else {
            return HorizonFinding(tiltDegrees: 0)
        }
        let degrees = Double(obs.angle) * 180 / .pi
        return HorizonFinding(tiltDegrees: degrees)
    }

    // MARK: - Saliency

    static func saliency(in image: CIImage) async -> SaliencyFinding? {
        let request = VNGenerateAttentionBasedSaliencyImageRequest()
        guard performSafely(request, on: image) else { return nil }
        guard let obs = request.results?.first,
              let salient = obs.salientObjects?.first else { return nil }
        let bb = salient.boundingBox
        return SaliencyFinding(
            attentionCenter: CGPoint(x: bb.midX, y: bb.midY),
            attentionArea: Double(bb.width * bb.height)
        )
    }

    // MARK: - Animal

    static func animal(in image: CIImage) async -> AnimalFinding? {
        let request = VNRecognizeAnimalsRequest()
        guard performSafely(request, on: image) else {
            return AnimalFinding(species: [])
        }
        let observations = request.results ?? []
        let species = observations.compactMap {
            $0.labels.first?.identifier.capitalized
        }
        return AnimalFinding(species: species)
    }

    // MARK: - Aesthetics (iOS 18+)

    static func aesthetics(in image: CIImage) async -> AestheticsFinding? {
        if #available(iOS 18.0, macOS 15.0, *) {
            let request = VNCalculateImageAestheticsScoresRequest()
            guard performSafely(request, on: image) else { return nil }
            guard let obs = request.results?.first else {
                return nil
            }
            return AestheticsFinding(
                overallScore: Double(obs.overallScore),
                isUtility: obs.isUtility
            )
        }
        return nil
    }

    // MARK: - Shared

    /// Runs one Vision request synchronously on the current cooperative
    /// thread. Returns false on failure so callers can short-circuit.
    private static func performSafely(_ request: VNRequest, on image: CIImage) -> Bool {
        let handler = VNImageRequestHandler(ciImage: image, orientation: .up, options: [:])
        do {
            try handler.perform([request])
            return true
        } catch {
            return false
        }
    }
}
