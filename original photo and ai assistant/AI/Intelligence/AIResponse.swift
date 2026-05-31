//
//  AIResponse.swift
//  AI Camera Coach — Intelligence layer
//

import Foundation

/// Everything the UI ever needs back from an AI engine. The text is what
/// the user sees; the provenance is what the user is *told*.
nonisolated struct AIResponse: Sendable, Hashable, Identifiable {
    let id = UUID()
    let text: String
    let provenance: AIProvenance
    let createdAt: Date

    init(text: String, provenance: AIProvenance, createdAt: Date = .now) {
        self.text = text
        self.provenance = provenance
        self.createdAt = createdAt
    }
}
