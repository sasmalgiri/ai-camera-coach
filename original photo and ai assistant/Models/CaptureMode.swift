//
//  CaptureMode.swift
//  AI Camera Coach
//

import Foundation

enum CaptureMode: String, CaseIterable, Identifiable, Hashable, Codable {
    case smart
    case family
    case child
    case pet
    case travel

    var id: String { rawValue }

    var title: String {
        switch self {
        case .smart: return "Smart"
        case .family: return "Family"
        case .child: return "Child"
        case .pet: return "Pet"
        case .travel: return "Travel"
        }
    }

    var subtitle: String {
        switch self {
        case .smart: return "General-purpose AI capture"
        case .family: return "Group photos with multiple faces"
        case .child: return "Moving kids, unpredictable moments"
        case .pet: return "Animals and fast subjects"
        case .travel: return "Landmarks and scenery"
        }
    }

    var symbolName: String {
        switch self {
        case .smart: return "sparkles"
        case .family: return "person.3.fill"
        case .child: return "figure.child"
        case .pet: return "pawprint.fill"
        case .travel: return "mountain.2.fill"
        }
    }
}
