//
//  ExpertOrchestrator.swift
//  AI Camera Coach — MoE layer
//
//  Mode-aware gate: picks which experts fire for a given capture mode,
//  then runs them in parallel via a TaskGroup. Returns a fully-populated
//  ExpertFindings struct.
//

import CoreImage
import Foundation
import UIKit

actor ExpertOrchestrator {

    /// Which experts fire for each mode. "Smart" runs all of them.
    static func experts(for mode: CaptureMode) -> Set<ExpertKind> {
        switch mode {
        case .original:
            // User wants raw — but if they ask the AI Expert, still
            // run the full set so the explanation is rich.
            return Set(ExpertKind.allCases)
        case .smart:
            return Set(ExpertKind.allCases)
        case .family, .child:
            return [.face, .saliency, .aesthetics, .horizon, .nlp]
        case .pet:
            return [.animal, .face, .saliency, .aesthetics]
        case .travel:
            return [.classification, .horizon, .ocr, .nlp, .aesthetics, .saliency]
        }
    }

    /// Runs the gated experts in parallel and returns merged findings.
    /// Vision requests are CPU-bound — TaskGroup actually spreads them
    /// across cores on Apple silicon.
    func gather(from image: CIImage, mode: CaptureMode) async -> ExpertFindings {
        let active = Self.experts(for: mode)

        async let faceOut: FaceFinding? =
            active.contains(.face) ? VisionExperts.face(in: image) : nil
        async let ocrOut: OCRFinding? =
            active.contains(.ocr) ? VisionExperts.ocr(in: image) : nil
        async let classOut: ClassificationFinding? =
            active.contains(.classification) ? VisionExperts.classification(in: image) : nil
        async let horizonOut: HorizonFinding? =
            active.contains(.horizon) ? VisionExperts.horizon(in: image) : nil
        async let saliencyOut: SaliencyFinding? =
            active.contains(.saliency) ? VisionExperts.saliency(in: image) : nil
        async let animalOut: AnimalFinding? =
            active.contains(.animal) ? VisionExperts.animal(in: image) : nil
        async let aestheticsOut: AestheticsFinding? =
            active.contains(.aesthetics) ? VisionExperts.aesthetics(in: image) : nil

        var findings = ExpertFindings()
        findings.face = await faceOut
        findings.ocr = await ocrOut
        findings.classification = await classOut
        findings.horizon = await horizonOut
        findings.saliency = await saliencyOut
        findings.animal = await animalOut
        findings.aesthetics = await aestheticsOut

        // NLP runs on extracted text — depends on OCR and Classification.
        if active.contains(.nlp) {
            var text = ""
            if let snippets = findings.ocr?.snippets, !snippets.isEmpty {
                text += snippets.joined(separator: " ")
            }
            if let labels = findings.classification?.labels, !labels.isEmpty {
                text += " " + labels.joined(separator: " ")
            }
            findings.nlp = NLPExpert.analyze(text: text.trimmingCharacters(in: .whitespaces))
        }

        return findings
    }

    /// Convenience wrapper for callers holding JPEG data.
    func gather(jpegData: Data, mode: CaptureMode) async -> ExpertFindings? {
        guard let uiImage = UIImage(data: jpegData),
              let cg = uiImage.cgImage else { return nil }
        let ci = CIImage(cgImage: cg)
        return await gather(from: ci, mode: mode)
    }
}
