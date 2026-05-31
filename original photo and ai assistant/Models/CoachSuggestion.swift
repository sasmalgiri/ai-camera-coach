//
//  CoachSuggestion.swift
//  AI Camera Coach
//

import Foundation

struct CoachSuggestion: Identifiable, Hashable {
    enum Priority: Int, Comparable {
        case info, suggestion, important
        static func < (lhs: Priority, rhs: Priority) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    let id = UUID()
    let icon: String
    let message: String
    let priority: Priority
}
