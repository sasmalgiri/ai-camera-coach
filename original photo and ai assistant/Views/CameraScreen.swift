//
//  CameraScreen.swift
//  AI Camera Coach
//

import AVFoundation
import SwiftUI
import UIKit

struct CameraScreen: View {
    @Bindable var viewModel: CameraViewModel
    @Bindable var aiSettings: AISettingsStore
    let switchToGallery: () -> Void

    @State private var levelService = DeviceLevelService()
    @State private var showModeSheet = false
    @State private var showSettings = false
    @State private var showHelp = false
    @State private var pinchBaseline: CGFloat = 1.0

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.ignoresSafeArea()

                if viewModel.isAuthorized {
                    CameraPreviewView(session: viewModel.session)
                        .ignoresSafeArea()
                        .gesture(tapGesture(in: geo))
                        .simultaneousGesture(pinchGesture)

                    CompositionOverlay(showGrid: viewModel.showGrid,
                                       showLevel: viewModel.showLevel,
                                       rollDegrees: levelService.rollDegrees)
                        .ignoresSafeArea()

                    if let p = viewModel.focusReticleNormalised {
                        FocusReticle()
                            .position(x: p.x * geo.size.width,
                                      y: p.y * geo.size.height)
                            .transition(.opacity)
                    }
                } else {
                    permissionPrompt
                }

                VStack {
                    topBar
                    if let suggested = viewModel.suggestedMode {
                        modeSuggestionBanner(suggested)
                            .padding(.horizontal)
                            .padding(.top, 8)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    Spacer()
                    if viewModel.showCoach && viewModel.isAuthorized {
                        CoachPanel(score: viewModel.photoScore.total,
                                   suggestions: viewModel.suggestions)
                            .padding(.horizontal)
                            .padding(.bottom, 8)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    } else if viewModel.showProactiveTip {
                        proactiveTipBubble(viewModel.proactiveTipText)
                            .padding(.horizontal)
                            .padding(.bottom, 8)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                    if let feedback = viewModel.captureFeedback {
                        captureFeedbackBubble(feedback)
                            .padding(.bottom, 8)
                    }
                    if viewModel.countdownRemaining > 0 {
                        Text("\(viewModel.countdownRemaining)")
                            .font(.system(size: 72, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                            .shadow(radius: 8)
                    }
                    bottomBar
                }
                .padding(.vertical, 12)
            }
        }
        .task {
            await viewModel.bootstrap()
            levelService.start()
        }
        .onDisappear {
            viewModel.stop()
            levelService.stop()
        }
        .onAppear { viewModel.resume() }
        .sheet(isPresented: $showModeSheet) {
            ModePicker(selected: $viewModel.mode)
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $showSettings) {
            SettingsScreen(autoCorrection: $viewModel.autoCorrectionEnabled,
                           flash: $viewModel.captureFlash,
                           showGrid: $viewModel.showGrid,
                           showLevel: $viewModel.showLevel,
                           saveToPhotos: $viewModel.saveToPhotos,
                           aiSettings: aiSettings)
                .presentationDetents([.large])
        }
        .sheet(isPresented: $viewModel.showAIInsight) {
            AICoachInsightSheet(service: viewModel.coach,
                                onClose: { viewModel.showAIInsight = false })
        }
        .sheet(isPresented: $showHelp) {
            HelpSheet()
        }
    }

    // MARK: - Gestures

    private func tapGesture(in geo: GeometryProxy) -> some Gesture {
        SpatialTapGesture()
            .onEnded { value in
                let normalised = CGPoint(
                    x: value.location.x / geo.size.width,
                    y: value.location.y / geo.size.height
                )
                viewModel.focus(atNormalisedScreenPoint: normalised)
            }
    }

    private var pinchGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                let next = pinchBaseline * value
                viewModel.setZoom(next)
            }
            .onEnded { _ in
                pinchBaseline = viewModel.session.inputs.first
                    .flatMap { ($0 as? AVCaptureDeviceInput)?.device.videoZoomFactor } ?? 1.0
            }
    }

    // MARK: - Top bar / bottom bar

    private var permissionPrompt: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.aperture")
                .font(.system(size: 64))
                .foregroundStyle(.white.opacity(0.8))
            Text("AI Camera Coach needs camera access")
                .font(.headline)
                .foregroundStyle(.white)
            Text("Enable Camera access in Settings to start capturing great photos.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.75))
                .padding(.horizontal, 32)
            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                Text("Open Settings")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(.white, in: Capsule())
                    .foregroundStyle(.black)
            }
        }
    }

    private var topBar: some View {
        HStack {
            modeChip
            Spacer()
            iconButton(systemName: timerSymbol) { viewModel.cycleTimer() }
                .overlay(alignment: .bottomTrailing) {
                    if viewModel.timerSeconds > 0 {
                        Text("\(viewModel.timerSeconds)")
                            .font(.caption2.bold())
                            .foregroundStyle(.black)
                            .padding(.horizontal, 4)
                            .background(.yellow, in: Capsule())
                            .offset(x: 4, y: 4)
                    }
                }
            iconButton(systemName: "questionmark") { showHelp = true }
            iconButton(systemName: "arrow.triangle.2.circlepath.camera") {
                viewModel.switchCamera()
            }
            iconButton(systemName: "slider.horizontal.3") { showSettings = true }
        }
        .padding(.horizontal)
    }

    private var timerSymbol: String {
        switch viewModel.timerSeconds {
        case 3: return "3.circle"
        case 10: return "10.circle"
        default: return "timer"
        }
    }

    private var modeChip: some View {
        Button {
            showModeSheet = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: viewModel.mode.symbolName)
                Text(viewModel.mode.title)
                    .font(.subheadline.weight(.semibold))
                Image(systemName: "chevron.down").font(.caption)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial, in: Capsule())
        }
    }

    private var bottomBar: some View {
        HStack(alignment: .center) {
            galleryButton
            Spacer()
            captureButton
            Spacer()
            aiButtonStack
        }
        .padding(.horizontal, 28)
    }

    private var galleryButton: some View {
        Button(action: switchToGallery) {
            Group {
                if let last = viewModel.lastCaptured,
                   let img = viewModel.library.processedImage(for: last) {
                    Image(uiImage: img).resizable().scaledToFill()
                } else {
                    Image(systemName: "photo.stack").font(.title2).foregroundStyle(.white)
                }
            }
            .frame(width: 54, height: 54)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.6), lineWidth: 1))
        }
        .accessibilityLabel("Open Gallery")
    }

    private var captureButton: some View {
        Button {
            viewModel.capture()
        } label: {
            ZStack {
                Circle().stroke(.white, lineWidth: 4).frame(width: 84, height: 84)
                Circle()
                    .fill(viewModel.aiPhotographerEnabled ? Color.green : Color.white)
                    .frame(width: 70, height: 70)
            }
        }
        .accessibilityLabel("Capture photo")
    }

    private var aiButtonStack: some View {
        VStack(spacing: 8) {
            Button {
                viewModel.askAIExpert()
            } label: {
                Image(systemName: "sparkles")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.yellow)
                    .frame(width: 54, height: 38)
                    .background(.ultraThinMaterial, in: Capsule())
            }
            .accessibilityLabel("Ask AI Expert")

            Button {
                viewModel.toggleAIPhotographer()
            } label: {
                Image(systemName: viewModel.aiPhotographerEnabled
                      ? "wand.and.stars"
                      : "wand.and.stars.inverse")
                    .font(.title3)
                    .foregroundStyle(viewModel.aiPhotographerEnabled ? .green : .white)
                    .frame(width: 54, height: 38)
                    .background(.ultraThinMaterial, in: Capsule())
            }
            Button {
                viewModel.toggleCoach()
            } label: {
                Text("AI")
                    .font(.caption.bold())
                    .foregroundStyle(viewModel.showCoach ? .black : .white)
                    .frame(width: 54, height: 24)
                    .background(viewModel.showCoach
                                ? AnyShapeStyle(Color.white)
                                : AnyShapeStyle(Material.ultraThin))
                    .clipShape(Capsule())
            }
        }
    }

    private func iconButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.headline)
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(.ultraThinMaterial, in: Circle())
        }
    }

    private func captureFeedbackBubble(_ text: String) -> some View {
        Text(text)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.black.opacity(0.7), in: Capsule())
    }

    private func proactiveTipBubble(_ text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "lightbulb.fill").foregroundStyle(.yellow)
            Text(text)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14)
            .stroke(.yellow.opacity(0.45), lineWidth: 1))
    }

    private func modeSuggestionBanner(_ suggested: CaptureMode) -> some View {
        HStack(spacing: 12) {
            Image(systemName: suggested.symbolName).foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text("Try \(suggested.title) mode?")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Text(suggested.subtitle)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
            }
            Spacer()
            Button("Use") { viewModel.acceptModeSuggestion() }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            Button {
                viewModel.dismissModeSuggestion()
            } label: {
                Image(systemName: "xmark").font(.caption).foregroundStyle(.white)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Focus reticle

private struct FocusReticle: View {
    @State private var scale: CGFloat = 1.3
    var body: some View {
        RoundedRectangle(cornerRadius: 6)
            .stroke(.yellow, lineWidth: 1.5)
            .frame(width: 72, height: 72)
            .scaleEffect(scale)
            .animation(.spring(response: 0.25, dampingFraction: 0.5), value: scale)
            .onAppear { scale = 1.0 }
    }
}

