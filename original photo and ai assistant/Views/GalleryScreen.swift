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

    // Search / filter state.
    @State private var searchText = ""
    @State private var modeFilter: CaptureMode?
    @State private var minScore: Double = 0
    @State private var showFilters = false

    private let columns = [GridItem(.adaptive(minimum: 110), spacing: 4)]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                if library.entries.isEmpty {
                    emptyState
                } else {
                    VStack(spacing: 0) {
                        if showFilters { filterBar }
                        if filtered.isEmpty {
                            noMatches
                        } else {
                            grid
                        }
                    }
                }
            }
            .navigationTitle(navigationTitle)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar { toolbarContent }
            .searchable(text: $searchText, prompt: "Search by mode or score")
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

    // MARK: - Filtering

    private var filtered: [PhotoEntry] {
        library.entries.filter { entry in
            if let modeFilter, entry.mode != modeFilter { return false }
            if Double(entry.score) < minScore { return false }
            if !searchText.isEmpty {
                let q = searchText.lowercased()
                if !entry.mode.title.lowercased().contains(q) {
                    if let scoreInt = Int(q) {
                        if entry.score < scoreInt { return false }
                    } else {
                        return false
                    }
                }
            }
            return true
        }
    }

    private var navigationTitle: String {
        if isSelecting {
            return selection.isEmpty ? "Select" : "\(selection.count) selected"
        }
        if filtered.count != library.entries.count {
            return "\(filtered.count) of \(library.entries.count)"
        }
        return "Gallery"
    }

    private var filterBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Mode").font(.caption).foregroundStyle(.white.opacity(0.6))
                Spacer()
                if modeFilter != nil || minScore > 0 {
                    Button("Reset") {
                        modeFilter = nil
                        minScore = 0
                    }
                    .font(.caption)
                    .tint(.yellow)
                }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    chip(title: "All", isSelected: modeFilter == nil) {
                        modeFilter = nil
                    }
                    ForEach(CaptureMode.allCases) { mode in
                        chip(title: mode.title, isSelected: modeFilter == mode) {
                            modeFilter = (modeFilter == mode) ? nil : mode
                        }
                    }
                }
            }
            HStack {
                Text("Min score: \(Int(minScore))")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(width: 110, alignment: .leading)
                Slider(value: $minScore, in: 0...100, step: 5)
                    .tint(.yellow)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.black.opacity(0.4))
    }

    private func chip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .foregroundStyle(isSelected ? .black : .white)
                .background(isSelected ? AnyShapeStyle(Color.white)
                                       : AnyShapeStyle(Material.ultraThin),
                            in: Capsule())
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
        ToolbarItemGroup(placement: .topBarTrailing) {
            if !library.entries.isEmpty {
                if isSelecting {
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
                } else {
                    Button {
                        withAnimation { showFilters.toggle() }
                    } label: {
                        Image(systemName: showFilters
                              ? "line.3.horizontal.decrease.circle.fill"
                              : "line.3.horizontal.decrease.circle")
                    }
                    .tint(.white)
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
                ForEach(filtered) { entry in
                    let isChecked = selection.contains(entry.id)
                    Button {
                        if isSelecting { toggleSelection(entry) }
                        else { selected = entry }
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

    private var noMatches: some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: "magnifyingglass")
                .font(.system(size: 32))
                .foregroundStyle(.white.opacity(0.5))
            Text("No photos match your filters.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))
            Spacer()
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
