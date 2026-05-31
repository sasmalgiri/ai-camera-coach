//
//  AICoachService.swift
//  AI Camera Coach — Intelligence layer
//
//  The single high-level entry point view models call. It hides the
//  router and rebuilds it whenever settings change, so callers don't
//  have to think about the engine chain at all.
//

import Foundation
import Observation
import UIKit

@Observable
@MainActor
final class AICoachService {

    private(set) var lastResponse: AIResponse?
    private(set) var isWorking: Bool = false
    private(set) var lastError: String?

    @ObservationIgnored private let settings: AISettingsStore
    @ObservationIgnored private var currentTask: Task<Void, Never>?
    @ObservationIgnored private var forensicObserverTask: Task<Void, Never>?

    init(settings: AISettingsStore) {
        self.settings = settings

        // Kill-switch listener: when forensic mode flips on, cancel any
        // in-flight cloud call. Uses NotificationCenter's async sequence
        // so we don't need an Objective-C selector or escaping closure.
        forensicObserverTask = Task { [weak self] in
            let stream = NotificationCenter.default.notifications(
                named: .aiForensicModeEnabled
            )
            for await _ in stream {
                await MainActor.run { self?.cancelInFlight() }
            }
        }
    }

    deinit {
        forensicObserverTask?.cancel()
    }

    // MARK: - Public

    /// Generates a coaching insight for the given scene. The result is
    /// written to `lastResponse`. Cancels any earlier in-flight call.
    func askForCoaching(scene: SceneSummary) {
        startWork { router in
            await router.coachingAdvice(scene: scene)
        }
    }

    /// Explains a photo score in human terms.
    func askForScoreExplanation(score: PhotoScore, scene: SceneSummary) {
        startWork { router in
            await router.scoreExplanation(score: score, scene: scene)
        }
    }

    /// Generates a caption for a captured JPEG. Vision-required — will
    /// degrade to a generic line when cloud isn't allowed.
    func askForCaption(image: UIImage, mode: CaptureMode) {
        guard let data = image.jpegData(compressionQuality: 0.7) else { return }
        startWork { router in
            await router.photoCaption(imageJPEG: data, mode: mode)
        }
    }

    func clear() {
        cancelInFlight()
        lastResponse = nil
        lastError = nil
    }

    // MARK: - Internals

    private func startWork(_ work: @escaping @Sendable (AIRouter) async -> AIResponse) {
        cancelInFlight()
        isWorking = true
        lastError = nil
        let snapshot = AISettingsSnapshot(settings)
        currentTask = Task { @MainActor [weak self] in
            let router = AIRouter(settings: snapshot)
            let response = await work(router)
            guard let self, !Task.isCancelled else { return }
            self.lastResponse = response
            self.isWorking = false
        }
    }

    private func cancelInFlight() {
        currentTask?.cancel()
        currentTask = nil
        isWorking = false
    }
}
