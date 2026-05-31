//
//  ExpertFindings.swift
//  AI Camera Coach — MoE layer
//
//  Sendable container of evidence produced by the parallel experts.
//  This is what the Apple Intelligence brain reads.
//

import CoreGraphics
import Foundation

nonisolated struct ExpertFindings: Sendable, Hashable {

    // Specialist outputs — any can be nil if that expert wasn't run.
    var face: FaceFinding?
    var ocr: OCRFinding?
    var classification: ClassificationFinding?
    var horizon: HorizonFinding?
    var saliency: SaliencyFinding?
    var animal: AnimalFinding?
    var aesthetics: AestheticsFinding?
    var nlp: NLPFinding?

    /// Diagnostic — which experts actually produced output.
    var contributingExperts: [String] {
        var list: [String] = []
        if face != nil          { list.append("Face") }
        if ocr != nil           { list.append("OCR") }
        if classification != nil { list.append("Classification") }
        if horizon != nil       { list.append("Horizon") }
        if saliency != nil      { list.append("Saliency") }
        if animal != nil        { list.append("Animal") }
        if aesthetics != nil    { list.append("Aesthetics") }
        if nlp != nil           { list.append("NLP") }
        return list
    }
}

// MARK: - Individual findings

nonisolated struct FaceFinding: Sendable, Hashable {
    let count: Int
    let mostEyesOpen: Bool
    let mostSmiling: Bool
    /// Largest face bounding box (normalized) — useful for "centering" reasoning.
    let primaryBoundingBox: CGRect?

    var promptText: String {
        if count == 0 { return "Faces: none" }
        var parts = ["Faces: \(count)"]
        parts.append("most eyes open: \(mostEyesOpen ? "yes" : "no")")
        parts.append("most smiling: \(mostSmiling ? "yes" : "no")")
        if let bb = primaryBoundingBox {
            parts.append(String(format: "primary face at x=%.2f y=%.2f w=%.2f h=%.2f",
                                bb.midX, bb.midY, bb.width, bb.height))
        }
        return parts.joined(separator: ", ")
    }
}

nonisolated struct OCRFinding: Sendable, Hashable {
    let snippets: [String]    // Top-confidence recognized strings.

    var promptText: String {
        guard !snippets.isEmpty else { return "Text in frame: none" }
        let joined = snippets.prefix(5).joined(separator: " · ")
        return "Text in frame: \(joined)"
    }
}

nonisolated struct ClassificationFinding: Sendable, Hashable {
    /// (label, confidence) sorted by confidence desc.
    let labels: [String]

    var promptText: String {
        guard !labels.isEmpty else { return "Scene content: unclear" }
        return "Scene content: \(labels.prefix(5).joined(separator: ", "))"
    }
}

nonisolated struct HorizonFinding: Sendable, Hashable {
    let tiltDegrees: Double

    var promptText: String {
        if abs(tiltDegrees) < 1.5 { return "Horizon: level" }
        let dir = tiltDegrees > 0 ? "right" : "left"
        return String(format: "Horizon: tilted %.1f° to the %@", abs(tiltDegrees), dir)
    }
}

nonisolated struct SaliencyFinding: Sendable, Hashable {
    /// Normalized centroid of the main attention region (0..1).
    let attentionCenter: CGPoint
    let attentionArea: Double  // 0..1 — how big the main subject is.

    var promptText: String {
        String(format:
            "Attention: subject around (%.2f, %.2f), occupies %.0f%% of frame",
            attentionCenter.x, attentionCenter.y, attentionArea * 100)
    }
}

nonisolated struct AnimalFinding: Sendable, Hashable {
    /// e.g. ["Dog", "Cat"]
    let species: [String]

    var promptText: String {
        guard !species.isEmpty else { return "Animals: none detected" }
        return "Animals: \(species.joined(separator: ", "))"
    }
}

nonisolated struct AestheticsFinding: Sendable, Hashable {
    /// 0..1, higher = more aesthetic.
    let overallScore: Double
    let isUtility: Bool       // true means the image looks utility (screenshot/document)

    var promptText: String {
        String(format: "Aesthetic score: %.2f (utility: %@)",
               overallScore, isUtility ? "yes" : "no")
    }
}

nonisolated struct NLPFinding: Sendable, Hashable {
    let keywords: [String]    // From OCR text or labels.
    let dominantLanguage: String?

    var promptText: String {
        var parts: [String] = []
        if !keywords.isEmpty {
            parts.append("Keywords: \(keywords.prefix(5).joined(separator: ", "))")
        }
        if let lang = dominantLanguage {
            parts.append("Detected language: \(lang)")
        }
        return parts.isEmpty ? "No text-derived signals" : parts.joined(separator: "; ")
    }
}
