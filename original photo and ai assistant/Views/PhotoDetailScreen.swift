//
//  PhotoDetailScreen.swift
//  AI Camera Coach
//

import SwiftUI

struct PhotoDetailScreen: View {
    let entry: PhotoEntry
    let library: PhotoLibraryStore
    @Environment(\.dismiss) private var dismiss
    @State private var sliderPosition: CGFloat = 0.5
    @State private var sharePayload: SharePayload?

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
                    HStack {
                        Button {
                            if let img = library.processedImage(for: entry) {
                                sharePayload = SharePayload(image: img)
                            }
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                        }
                        .tint(.white)
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
            .sheet(item: $sharePayload) { payload in
                ActivityView(activityItems: [payload.image])
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if let processed = library.processedImage(for: entry),
           let original = library.originalImage(for: entry) {
            VStack(spacing: 12) {
                Spacer(minLength: 0)
                BeforeAfterSlider(before: original,
                                  after: processed,
                                  position: $sliderPosition)
                    .aspectRatio(processed.size, contentMode: .fit)
                Text("Score \(entry.score) · \(entry.mode.title)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Text("Drag the slider to compare Original ↔ Enhanced")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
                Spacer(minLength: 0)
            }
            .padding(.bottom, 24)
        } else {
            ProgressView().tint(.white)
        }
    }
}

// MARK: - Before/After Slider

private struct BeforeAfterSlider: View {
    let before: UIImage
    let after: UIImage
    @Binding var position: CGFloat   // 0..1

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Image(uiImage: before)
                    .resizable()
                    .scaledToFit()
                Image(uiImage: after)
                    .resizable()
                    .scaledToFit()
                    .mask(
                        Rectangle()
                            .frame(width: geo.size.width * position,
                                   alignment: .leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    )
                handle(in: geo)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let x = max(0, min(geo.size.width, value.location.x))
                        position = x / max(geo.size.width, 1)
                    }
            )
            .overlay(alignment: .topLeading) {
                Text("Original")
                    .font(.caption2.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6).padding(.vertical, 3)
                    .background(.black.opacity(0.5), in: Capsule())
                    .padding(8)
            }
            .overlay(alignment: .topTrailing) {
                Text("Enhanced")
                    .font(.caption2.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6).padding(.vertical, 3)
                    .background(.black.opacity(0.5), in: Capsule())
                    .padding(8)
            }
        }
    }

    private func handle(in geo: GeometryProxy) -> some View {
        let x = geo.size.width * position
        return ZStack {
            Rectangle().fill(.white).frame(width: 2)
            Circle()
                .fill(.white)
                .frame(width: 32, height: 32)
                .overlay(
                    HStack(spacing: 2) {
                        Image(systemName: "chevron.left")
                        Image(systemName: "chevron.right")
                    }
                    .font(.caption2.bold())
                    .foregroundStyle(.black)
                )
                .shadow(radius: 3)
        }
        .frame(width: 32, height: geo.size.height)
        .position(x: x, y: geo.size.height / 2)
    }
}

// MARK: - Share sheet

private struct SharePayload: Identifiable {
    let id = UUID()
    let image: UIImage
}

private struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
