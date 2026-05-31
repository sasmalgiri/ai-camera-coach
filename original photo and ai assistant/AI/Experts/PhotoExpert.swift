//
//  PhotoExpert.swift
//  AI Camera Coach — MoE layer
//

import Foundation

/// Identifier the orchestrator uses to gate which experts fire per mode.
nonisolated enum ExpertKind: String, Sendable, Hashable, CaseIterable {
    case face
    case ocr
    case classification
    case horizon
    case saliency
    case animal
    case aesthetics
    case nlp
}
