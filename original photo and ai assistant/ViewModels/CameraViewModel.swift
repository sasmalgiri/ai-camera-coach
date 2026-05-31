//
//  CameraViewModel.swift
//  AI Camera Coach
//

import AVFoundation
import CoreImage
import Observation
import SwiftUI
import UIKit

@Observable
@MainActor
final class CameraViewModel: CameraServiceDelegate {

    // MARK: - UI state

    var mode: CaptureMode = .smart
    var isAuthorized = false
    var isRunning = false
    var photoScore: PhotoScore = .zero
    var suggestions: [CoachSuggestion] = []
    var showCoach = false
    var autoCorrectionEnabled = true
    var aiPhotographerEnabled = false
    var captureFlash: AVCaptureDevice.FlashMode = .auto
    var captureFeedback: String?
    var lastCaptured: PhotoEntry?

    // MARK: - References

    @ObservationIgnored let session: AVCaptureSession
    @ObservationIgnored let library: PhotoLibraryStore

    // MARK: - Internals

    @ObservationIgnored private let cameraService = CameraService()
    @ObservationIgnored private let analyzer = SceneAnalyzer()
    @ObservationIgnored private let scorer = PhotoScorer()
    @ObservationIgnored private let advisor = CoachAdvisor()
    @ObservationIgnored private let corrector = AutoCorrector()
    @ObservationIgnored private let photographer = AIPhotographer()

    @ObservationIgnored private var analysisInFlight = false
    @ObservationIgnored private var lastAnalysisAt: Date = .distantPast
    @ObservationIgnored private let analysisInterval: TimeInterval = 0.7
    @ObservationIgnored private var currentAnalysis = SceneAnalysis()

    init(library: PhotoLibraryStore) {
        self.library = library
        self.session = cameraService.session
        self.cameraService.delegate = self
    }

    // MARK: - Lifecycle

    func bootstrap() async {
        isAuthorized = await cameraService.requestAuthorization()
        guard isAuthorized else { return }
        await cameraService.configure()
        cameraService.start()
        isRunning = true
    }

    func stop() {
        cameraService.stop()
        isRunning = false
    }

    func resume() {
        guard isAuthorized, isRunning == false else { return }
        cameraService.start()
        isRunning = true
    }

    // MARK: - Actions

    func capture() {
        cameraService.capturePhoto(flash: captureFlash)
    }

    func switchCamera() {
        cameraService.switchCamera()
    }

    func toggleAIPhotographer() {
        aiPhotographerEnabled.toggle()
        if aiPhotographerEnabled {
            photographer.enable()
            flashFeedback("AI Photographer ready", duration: 1.5)
        } else {
            photographer.disable()
        }
    }

    func toggleCoach() {
        withAnimation { showCoach.toggle() }
    }

    // MARK: - CameraServiceDelegate

    func cameraService(_ service: CameraService, didOutput frame: CIImage) {
        Task { [weak self] in
            await self?.handleFrame(frame)
        }
    }

    func cameraService(_ service: CameraService, didCapture original: UIImage) {
        handleCapture(original)
    }

    func cameraService(_ service: CameraService, didFail error: Error) {
        flashFeedback("Capture failed — try again", duration: 2.0)
        _ = error
    }

    // MARK: - Frame handling

    private func handleFrame(_ frame: CIImage) async {
        let now = Date()
        guard !analysisInFlight,
              now.timeIntervalSince(lastAnalysisAt) >= analysisInterval else { return }
        analysisInFlight = true
        lastAnalysisAt = now
        let result = await analyzer.analyze(frame)
        let nextScore = scorer.score(result, mode: mode)
        let nextTips = advisor.suggestions(for: result, mode: mode)
        currentAnalysis = result
        photoScore = nextScore
        suggestions = nextTips
        if photographer.shouldCapture(score: nextScore, analysis: result, mode: mode) {
            cameraService.capturePhoto(flash: captureFlash)
        }
        analysisInFlight = false
    }

    private func handleCapture(_ image: UIImage) {
        let processed = autoCorrectionEnabled ? corrector.apply(to: image, mode: mode) : image
        let savedScore = photoScore.total
        if let entry = library.save(original: image,
                                    processed: processed,
                                    mode: mode,
                                    score: savedScore) {
            lastCaptured = entry
            flashFeedback("Saved · Score \(savedScore)", duration: 1.6)
        } else {
            flashFeedback("Couldn't save photo", duration: 2.0)
        }
    }

    private func flashFeedback(_ text: String, duration: TimeInterval) {
        captureFeedback = text
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            await MainActor.run {
                if self?.captureFeedback == text {
                    self?.captureFeedback = nil
                }
            }
        }
    }
}
