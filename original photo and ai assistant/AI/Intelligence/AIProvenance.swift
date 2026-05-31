//
//  AIProvenance.swift
//  AI Camera Coach — Intelligence layer
//
//  Provenance is the "where did this come from" label that travels with
//  every AI output. Surfaces in the UI as a small badge so the user always
//  knows whether a tip was generated on-device or by a cloud provider.
//

import Foundation
import SwiftUI

nonisolated enum AIProvenance: Sendable, Hashable, Codable {
    case appleIntelligence           // FoundationModels (iOS 26+)
    case naturalLanguageFallback     // NLTagger + on-device templates
    case openAI(model: String)       // user's own key
    case anthropic(model: String)    // user's own key

    var displayName: String {
        switch self {
        case .appleIntelligence:        return "Apple Intelligence"
        case .naturalLanguageFallback:  return "On-Device · Templates"
        case .openAI(let model):        return "OpenAI · \(model)"
        case .anthropic(let model):     return "Anthropic · \(model)"
        }
    }

    var runsOnDevice: Bool {
        switch self {
        case .appleIntelligence, .naturalLanguageFallback: return true
        case .openAI, .anthropic: return false
        }
    }

    var icon: String {
        switch self {
        case .appleIntelligence:        return "apple.logo"
        case .naturalLanguageFallback:  return "iphone"
        case .openAI:                   return "cloud"
        case .anthropic:                return "cloud"
        }
    }

    var tint: Color {
        runsOnDevice ? .green : .blue
    }
}
