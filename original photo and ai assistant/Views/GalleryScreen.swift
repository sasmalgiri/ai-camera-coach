//
//  GalleryScreen.swift
//  AI Camera Coach
//

import SwiftUI

struct GalleryScreen: View {
    let library: PhotoLibraryStore
    let switchToCamera: () -> Void
    @State private var selected: PhotoEntry?

    private let columns = [GridItem(.adaptive(minimum: 110), spacing: 4)]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                if library.entries.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 4) {
                            ForEach(library.entries) { entry in
                                Button {
                                    selected = entry
                                } label: {
                                    thumbnail(for: entry)
                                }
                            }
                        }
                        .padding(4)
                    }
                }
            }
            .navigationTitle("Gallery")
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        switchToCamera()
                    } label: {
                        Label("Camera", systemImage: "camera")
                    }
                    .tint(.white)
                }
            }
            .sheet(item: $selected) { entry in
                PhotoDetailScreen(entry: entry, library: library)
            }
        }
    }

    private func thumbnail(for entry: PhotoEntry) -> some View {
        Group {
            if let img = library.processedImage(for: entry) {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
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
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
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
}
