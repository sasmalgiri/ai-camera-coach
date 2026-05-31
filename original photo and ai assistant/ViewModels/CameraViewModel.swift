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

    var mode: CaptureMode = .smart {
        didSet { if oldValue != mode { Haptics.selection() } }
    }
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

    /// AI Expert sheet visibility.
    var showAIInsight = false

    // Composition overlays.
    var showGrid: Bool {
        didSet { UserDefaults.standard.set(showGrid, forKey: "camera.showGrid") }
    }
    var showLevel: Bool {
        didSet { UserDefaults.standard.set(showLevel, forKey: "camera.showLevel") }
    }

    /// Save every photo to the system Photos library (opt-in).
    var saveToPhotos: Bool {
        didSet { UserDefaults.standard.set(saveToPhotos, forKey: "camera.saveToPhotos") }
    }

    /// Proactive coaching: when score is low for >1.5s, surface the top tip.
    var showProactiveTip = false
    var proactiveTipText: String = ""

    /// Mode-auto-detect suggestion banner.
    var suggestedMode: CaptureMode?

    /// Timer state — 0 = immediate, otherwise countdown in seconds.
    var timerSeconds: Int = 0
    var countdownRemaining: Int = 0

    /// Last tap-to-focus point in normalised 0..1 device coords (for the
    /// on-screen reticle). Nil = hide.
    var focusReticleNormalised: CGPoint?

    /// Reduced operation mode when device gets hot.
    private(set) var isThermallyThrottled = false

    /// Most recent reason from the AI Photographer (visible in the AI
    /// Expert sheet when the auto-photographer is on).
    var photographerReason: String { photographer.lastDecisionReason }

    // MARK: - References

    @ObservationIgnored let session: AVCaptureSession
    @ObservationIgnored let library: PhotoLibraryStore
    @ObservationIgnored let coach: AICoachService

    // MARK: - Internals

    @ObservationIgnored private let cameraService = CameraService()
    @ObservationIgnored private let analyzer = SceneAnalyzer()
    @ObservationIgnored private let scorer = PhotoScorer()
    @ObservationIgnored private let advisor = CoachAdvisor()
    @ObservationIgnored private let corrector = AutoCorrector()
    @ObservationIgnored private let photographer = AIPhotographer()

    @ObservationIgnored private var analysisInFlight = false
    @ObservationIgnored private var lastAnalysisAt: Date = .distantPast
    @ObservationIgnored private var analysisInterval: TimeInterval = 0.7
    @ObservationIgnored private var currentAnalysis = SceneAnalysis()

    @ObservationIgnored private var latestSnapshotJPEG: Data?
    @ObservationIgnored private var lastSnapshotAt: Date = .distantPast
    @ObservationIgnored private let snapshotInterval: TimeInterval = 2.0
    @ObservationIgnored private let snapshotContext = CIContext()

    @ObservationIgnored private var lowScoreStartedAt: Date?
    @ObservationIgnored private var thermalObserver: NSObjectProtocol?

    init(library: PhotoLibraryStore, coach: AICoachService) {
        self.library = library
        self.coach = coach
        self.session = cameraService.session
        self.showGrid = UserDefaults.standard.bool(forKey: "camera.showGrid")
        self.showLevel = UserDefaults.standard.bool(forKey: "camera.showLevel")
        self.saveToPhotos = UserDefaults.standard.bool(forKey: "camera.saveToPhotos")
        self.cameraService.delegate = self

        // Adapt to thermal pressure on the device.
        thermalObserver = NotificationCenter.default.addObserver(
            forName: ProcessInfo.thermalStateDidChangeNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor [weak self] in self?.handleThermalChange() }
        }
        handleThermalChange()
    }

    deinit {
        if let observer = thermalObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Lifecycle

    func bootstrap() async {
        // App Intents / Shortcuts can pre-select a mode by setting this
        // before launch. Consume it once.
        if let requested = UserDefaults.standard.string(forKey: "camera.requestedMode"),
           let resolved = CaptureMode(rawValue: requested) {
            mode = resolved
            UserDefaults.standard.removeObject(forKey: "camera.requestedMode")
        }
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

    /// Capture, honouring the timer. Used by both the shutter button and
    /// the volume-button publisher.
    func capture() {
        guard timerSeconds > 0 else {
            performCapture()
            return
        }
        countdownRemaining = timerSeconds
        Task { @MainActor [weak self] in
            while let self, self.countdownRemaining > 0 {
                Haptics.impact(.light)
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                self.countdownRemaining -= 1
            }
            self?.performCapture()
        }
    }

    private func performCapture() {
        Haptics.impact(.medium)
        cameraService.capturePhoto(flash: captureFlash)
    }

    func switchCamera() {
        Haptics.selection()
        cameraService.switchCamera()
    }

    func toggleAIPhotographer() {
        aiPhotographerEnabled.toggle()
        Haptics.selection()
        if aiPhotographerEnabled {
            photographer.enable()
            flashFeedback("AI Photographer ready", duration: 1.5)
        } else {
            photographer.disable()
        }
    }

    func toggleCoach() {
        withAnimation { showCoach.toggle() }
        Haptics.selection()
    }

    /// Tap-to-focus. Point is normalised in screen coords (0..1), and we
    /// hand AVFoundation the camera-space point.
    func focus(atNormalisedScreenPoint p: CGPoint) {
        focusReticleNormalised = p
        // AVFoundation expects (x=right, y=down) in normalised camera
        // coords; for a portrait preview those are screen.y, 1 - screen.x.
        let cameraPoint = CGPoint(x: p.y, y: 1.0 - p.x)
        cameraService.focusAndExpose(at: cameraPoint)
        Haptics.impact(.soft)
        // Hide the reticle after a moment.
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            self?.focusReticleNormalised = nil
        }
    }

    func setZoom(_ factor: CGFloat) {
        cameraService.setZoom(factor)
    }

    func cycleTimer() {
        switch timerSeconds {
        case 0: timerSeconds = 3
        case 3: timerSeconds = 10
        default: timerSeconds = 0
        }
        Haptics.selection()
    }

    func askAIExpert() {
        let summary = SceneSummary.make(from: currentAnalysis, mode: mode, score: photoScore)
        coach.askForCoaching(scene: summary, imageJPEG: latestSnapshotJPEG)
        showAIInsight = true
        Haptics.selection()
    }

    func askAIExplainScore() {
        let summary = SceneSummary.make(from: currentAnalysis, mode: mode, score: photoScore)
        coach.askForScoreExplanation(score: photoScore,
                                     scene: summary,
                                     imageJPEG: latestSnapshotJPEG)
        showAIInsight = true
    }

    func acceptModeSuggestion() {
        if let suggested = suggestedMode {
            mode = suggested
            suggestedMode = nil
            flashFeedback("Switched to \(suggested.title) mode", duration: 1.4)
        }
    }

    func dismissModeSuggestion() { suggestedMode = nil }

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
        Haptics.notify(.error)
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

        updateProactiveTip(score: nextScore.total, tip: nextTips.first)
        updateModeSuggestion(from: result)

        if now.timeIntervalSince(lastSnapshotAt) >= snapshotInterval {
            lastSnapshotAt = now
            latestSnapshotJPEG = encodeJPEG(from: frame)
        }

        if photographer.shouldCapture(score: nextScore, analysis: result, mode: mode) {
            Haptics.notify(.success)
            performCapture()
        }
        analysisInFlight = false
    }

    private func encodeJPEG(from ciImage: CIImage) -> Data? {
        guard let cg = snapshotContext.createCGImage(ciImage, from: ciImage.extent) else {
            return nil
        }
        return UIImage(cgImage: cg).jpegData(compressionQuality: 0.7)
    }

    private func handleCapture(_ image: UIImage) {
        let processed: UIImage = {
            if mode.bypassesAutoCorrection { return image }
            return autoCorrectionEnabled ? corrector.apply(to: image, mode: mode) : image
        }()
        let savedScore = photoScore.total
        if let entry = library.save(original: image,
                                    processed: processed,
                                    mode: mode,
                                    score: savedScore) {
            lastCaptured = entry
            Haptics.notify(.success)
            flashFeedback("Saved · Score \(savedScore)", duration: 1.6)
            if saveToPhotos {
                let outImage = processed
                Task { [weak self] in
                    let ok = await SystemPhotoSaver.save(outImage)
                    if !ok {
                        await MainActor.run {
                            self?.flashFeedback("Couldn't save to Photos library", duration: 2.0)
                        }
                    }
                }
            }
        } else {
            Haptics.notify(.error)
            flashFeedback("Couldn't save photo", duration: 2.0)
        }
    }

    // MARK: - Proactive coach

    private func updateProactiveTip(score: Int, tip: CoachSuggestion?) {
        // Hide if user already has the coach panel open.
        if showCoach {
            showProactiveTip = false
            lowScoreStartedAt = nil
            return
        }
        if score < 45, let tip {
            if let started = lowScoreStartedAt {
                if Date().timeIntervalSince(started) > 1.5 {
                    if !showProactiveTip { Haptics.impact(.soft) }
                    proactiveTipText = tip.message
                    showProactiveTip = true
                    VoiceTipsService.shared.speak(tip.message)
                }
            } else {
                lowScoreStartedAt = Date()
            }
        } else {
            lowScoreStartedAt = nil
            if showProactiveTip { showProactiveTip = false }
        }
    }

    // MARK: - Mode auto-detect

    private func updateModeSuggestion(from analysis: SceneAnalysis) {
        // Only suggest if the user hasn't manually overridden recently.
        guard suggestedMode == nil else { return }
        let suggestion: CaptureMode? = {
            if analysis.faceCount >= 3 { return .family }
            if analysis.faceCount == 0 && mode != .travel { return .travel }
            return nil
        }()
        if let suggestion, suggestion != mode {
            suggestedMode = suggestion
        }
    }

    // MARK: - Thermal management

    private func handleThermalChange() {
        let state = ProcessInfo.processInfo.thermalState
        UIDevice.current.isBatteryMonitoringEnabled = true
        let batteryLevel = UIDevice.current.batteryLevel  // -1 if unknown
        let lowBattery = batteryLevel >= 0 && batteryLevel < 0.20

        switch state {
        case .nominal, .fair:
            isThermallyThrottled = false
            analysisInterval = lowBattery ? 1.4 : 0.7
        case .serious:
            isThermallyThrottled = true
            analysisInterval = lowBattery ? 2.0 : 1.4
        case .critical:
            isThermallyThrottled = true
            analysisInterval = lowBattery ? 3.5 : 2.5
        @unknown default:
            isThermallyThrottled = false
            analysisInterval = lowBattery ? 1.4 : 0.7
        }
    }

    // MARK: - Feedback

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
