//
//  RootView.swift
//  AI Camera Coach
//

import SwiftUI

struct RootView: View {

    enum Screen: Hashable { case camera, gallery }

    @State private var library: PhotoLibraryStore
    @State private var camera: CameraViewModel
    @State private var screen: Screen = .camera

    init() {
        let lib = PhotoLibraryStore()
        _library = State(initialValue: lib)
        _camera = State(initialValue: CameraViewModel(library: lib))
    }

    var body: some View {
        ZStack {
            switch screen {
            case .camera:
                CameraScreen(viewModel: camera,
                             switchToGallery: { screen = .gallery })
            case .gallery:
                GalleryScreen(library: library,
                              switchToCamera: { screen = .camera })
            }
        }
        .background(Color.black.ignoresSafeArea())
        .preferredColorScheme(.dark)
    }
}
