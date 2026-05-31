//
//  RootView.swift
//  AI Camera Coach
//

import SwiftUI

struct RootView: View {

    enum Screen: Hashable { case camera, gallery }

    @State private var library: PhotoLibraryStore
    @State private var aiSettings: AISettingsStore
    @State private var aiCoach: AICoachService
    @State private var camera: CameraViewModel
    @State private var screen: Screen = .camera

    init() {
        let lib = PhotoLibraryStore()
        let settings = AISettingsStore()
        let coach = AICoachService(settings: settings)
        _library = State(initialValue: lib)
        _aiSettings = State(initialValue: settings)
        _aiCoach = State(initialValue: coach)
        _camera = State(initialValue: CameraViewModel(library: lib, coach: coach))
    }

    var body: some View {
        ZStack {
            switch screen {
            case .camera:
                CameraScreen(viewModel: camera,
                             aiSettings: aiSettings,
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
