//
//  PhotoLibraryStore.swift
//  AI Camera Coach
//

import Foundation
import Observation
import UIKit

@Observable
@MainActor
final class PhotoLibraryStore {

    private(set) var entries: [PhotoEntry] = []

    @ObservationIgnored private let fileManager = FileManager.default
    @ObservationIgnored private let imagesDir: URL
    @ObservationIgnored private let indexURL: URL

    init() {
        let docs = fileManager.urls(for: .documentDirectory,
                                    in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        imagesDir = docs.appendingPathComponent("Photos", isDirectory: true)
        indexURL = docs.appendingPathComponent("photos.json")
        try? fileManager.createDirectory(at: imagesDir, withIntermediateDirectories: true)
        load()
    }

    @discardableResult
    func save(original: UIImage,
              processed: UIImage,
              mode: CaptureMode,
              score: Int) -> PhotoEntry? {
        let entry = PhotoEntry.new(mode: mode, score: score)
        let originalURL = imagesDir.appendingPathComponent(entry.originalFilename)
        let processedURL = imagesDir.appendingPathComponent(entry.processedFilename)

        guard let originalData = original.jpegData(compressionQuality: 0.95),
              let processedData = processed.jpegData(compressionQuality: 0.95) else {
            return nil
        }
        do {
            try originalData.write(to: originalURL, options: .atomic)
            try processedData.write(to: processedURL, options: .atomic)
            entries.insert(entry, at: 0)
            persist()
            return entry
        } catch {
            return nil
        }
    }

    func delete(_ entry: PhotoEntry) {
        try? fileManager.removeItem(at: imagesDir.appendingPathComponent(entry.originalFilename))
        try? fileManager.removeItem(at: imagesDir.appendingPathComponent(entry.processedFilename))
        entries.removeAll { $0.id == entry.id }
        persist()
    }

    func originalImage(for entry: PhotoEntry) -> UIImage? {
        UIImage(contentsOfFile:
            imagesDir.appendingPathComponent(entry.originalFilename).path)
    }

    func processedImage(for entry: PhotoEntry) -> UIImage? {
        UIImage(contentsOfFile:
            imagesDir.appendingPathComponent(entry.processedFilename).path)
    }

    // MARK: - Persistence

    private func load() {
        guard let data = try? Data(contentsOf: indexURL),
              let decoded = try? JSONDecoder().decode([PhotoEntry].self, from: data)
        else { return }
        entries = decoded
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: indexURL, options: .atomic)
    }
}
