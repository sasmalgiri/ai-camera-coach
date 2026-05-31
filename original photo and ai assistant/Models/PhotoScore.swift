//
//  PhotoScore.swift
//  AI Camera Coach
//

import Foundation

nonisolated struct PhotoScore: Equatable, Sendable {
    let total: Int                  // 0..100
    let breakdown: [String: Int]

    static let zero = PhotoScore(total: 0, breakdown: [:])
}
