//
//  PhotoScore.swift
//  AI Camera Coach
//

import Foundation

struct PhotoScore: Equatable {
    let total: Int                  // 0..100
    let breakdown: [String: Int]

    static let zero = PhotoScore(total: 0, breakdown: [:])
}
