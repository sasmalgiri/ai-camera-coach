//
//  PhotoDetailScreen.swift
//  AI Camera Coach
//

import SwiftUI

struct PhotoDetailScreen: View {
    let entry: PhotoEntry
    let library: PhotoLibraryStore
    @Environment(\.dismiss) private var dismiss
    @State private var showOriginal = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                content
            }
            .navigationTitle(entry.mode.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.black, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                        .tint(.white)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .destructive) {
                        library.delete(entry)
                        dismiss()
                    } label: {
                        Image(systemName: "trash")
                    }
                    .tint(.red)
                }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if let processed = library.processedImage(for: entry),
           let original = library.originalImage(for: entry) {
            VStack(spacing: 12) {
                Spacer(minLength: 0)
                Image(uiImage: showOriginal ? original : processed)
                    .resizable()
                    .scaledToFit()
                    .gesture(LongPressGesture(minimumDuration: 0.05)
                        .onChanged { _ in showOriginal = true }
                        .onEnded { _ in showOriginal = false })
                Text(showOriginal ? "Original" : "Enhanced · Score \(entry.score)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Text("Hold to compare with the original")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
                Spacer(minLength: 0)
            }
            .padding(.bottom, 24)
        } else {
            ProgressView()
                .tint(.white)
        }
    }
}
