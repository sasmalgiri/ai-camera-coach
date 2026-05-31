//
//  GalleryScreen.swift
//  AI Camera Coach
//

import SwiftUI
import UIKit

struct GalleryScreen: View {
    let library: PhotoLibraryStore
    let switchToCamera: () -> Void
    @State private var selected: PhotoEntry?
    @State private var isSelecting = false
    @State private var selection: Set<PhotoEntry.ID> = []
    @State private var shareItems: ShareItems?
    @State private var showDeleteAlert = false

    private let columns = [GridItem(.adaptive(minimum: 110), spacing: 4)]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                if library.entries.isEmpty {
                    emptyState
                } else {
                    grid
                }
            }
            .navigationTitle(isSelecting
                             ? (selection.isEmpty ? "Select" : "\(selection.count) selected")
                             : "Gallery")
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar { toolbarContent }
            .sheet(item: $selected) { entry in
                PhotoDetailScreen(entry: entry, library: library)
            }
            .sheet(item: $shareItems) { items in
                ActivityViewRepresentable(items: items.images)
            }
            .alert("Delete \(selection.count) photo\(selection.count == 1 ? "" : "s")?",
                   isPresented: $showDeleteAlert) {
                Button("Delete", role: .destructive) { performDelete() }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This can't be undone.")
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            if !isSelecting {
                Button {
                    switchToCamera()
                } label: { Label("Camera", systemImage: "camera") }
                    .tint(.white)
            } else {
                Button("Done") {
                    isSelecting = false
                    selection.removeAll()
                }
                .tint(.white)
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            if !library.entries.isEmpty {
                if isSelecting {
                    HStack {
                        Button {
                            shareSelected()
                        } label: { Image(systemName: "square.and.arrow.up") }
                            .disabled(selection.isEmpty)
                            .tint(.white)
                        Button(role: .destructive) {
                            showDeleteAlert = true
                        } label: { Image(systemName: "trash") }
                            .disabled(selection.isEmpty)
                            .tint(.red)
                    }
                } else {
                    Button("Select") {
                        isSelecting = true
                        selection.removeAll()
                    }
                    .tint(.white)
                }
            }
        }
    }

    private var grid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(library.entries) { entry in
                    let isChecked = selection.contains(entry.id)
                    Button {
                        if isSelecting {
                            toggleSelection(entry)
                        } else {
                            selected = entry
                        }
                    } label: {
                        thumbnail(for: entry, checked: isChecked)
                    }
                }
            }
            .padding(4)
        }
    }

    private func thumbnail(for entry: PhotoEntry, checked: Bool) -> some View {
        Group {
            if let img = library.processedImage(for: entry) {
                Image(uiImage: img).resizable().scaledToFill()
            } else {
                Color.gray.opacity(0.3)
            }
        }
        .frame(height: 120)
        .clipped()
        .overlay(alignment: .bottomTrailing) {
            Text("\(entry.score)")
                .font(.caption2.bold())
                .foregroundStyle(.white)
                .padding(.horizontal, 6).padding(.vertical, 3)
                .background(.black.opacity(0.6), in: Capsule())
                .padding(6)
        }
        .overlay(alignment: .topLeading) {
            Image(systemName: entry.mode.symbolName)
                .font(.caption)
                .foregroundStyle(.white)
                .padding(5)
                .background(.black.opacity(0.45), in: Circle())
                .padding(5)
        }
        .overlay(alignment: .topTrailing) {
            if isSelecting {
                Image(systemName: checked ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(checked ? .green : .white)
                    .padding(6)
                    .background(.black.opacity(0.4), in: Circle())
                    .padding(4)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 56))
                .foregroundStyle(.white.opacity(0.55))
            Text("No photos yet")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
            Text("Capture a photo and it will appear here.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.6))
            Button(action: switchToCamera) {
                Text("Open Camera")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(.white, in: Capsule())
                    .foregroundStyle(.black)
            }
            .padding(.top, 8)
        }
    }

    // MARK: - Selection helpers

    private func toggleSelection(_ entry: PhotoEntry) {
        if selection.contains(entry.id) { selection.remove(entry.id) }
        else { selection.insert(entry.id) }
        Haptics.selection()
    }

    private func shareSelected() {
        let images = library.entries
            .filter { selection.contains($0.id) }
            .compactMap { library.processedImage(for: $0) }
        guard !images.isEmpty else { return }
        shareItems = ShareItems(images: images)
    }

    private func performDelete() {
        let entries = library.entries.filter { selection.contains($0.id) }
        for entry in entries { library.delete(entry) }
        selection.removeAll()
        Haptics.notify(.success)
    }
}

// MARK: - Share helpers

private struct ShareItems: Identifiable {
    let id = UUID()
    let images: [UIImage]
}

private struct ActivityViewRepresentable: UIViewControllerRepresentable {
    let items: [UIImage]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
