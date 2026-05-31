//
//  PhotoEntry.swift
//  AI Camera Coach
//

import Foundation

nonisolated struct PhotoEntry: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    let createdAt: Date
    let modeRaw: String
    let score: Int
    let originalFilename: String
    let processedFilename: String

    var mode: CaptureMode { CaptureMode(rawValue: modeRaw) ?? .smart }

    static func new(mode: CaptureMode, score: Int) -> PhotoEntry {
        let id = UUID()
        return PhotoEntry(
            id: id,
            createdAt: Date(),
            modeRaw: mode.rawValue,
            score: score,
            originalFilename: "\(id.uuidString)-original.jpg",
            processedFilename: "\(id.uuidString)-processed.jpg"
        )
    }
}
