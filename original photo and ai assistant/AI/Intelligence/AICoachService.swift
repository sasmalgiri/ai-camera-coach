//
//  AICoachService.swift
//  AI Camera Coach — Intelligence layer
//

import Foundation
import Observation
import UIKit

@Observable
@MainActor
final class AICoachService {

    private(set) var lastResponse: AIResponse?
    private(set) var partialText: String = ""
    private(set) var isWorking: Bool = false
    private(set) var lastError: String?

    @ObservationIgnored private let settings: AISettingsStore
    @ObservationIgnored private var currentTask: Task<Void, Never>?
    @ObservationIgnored private var forensicObserverTask: Task<Void, Never>?
    @ObservationIgnored private let prewarmBrain = ParallelAppleBrain()

    init(settings: AISettingsStore) {
        self.settings = settings
        forensicObserverTask = Task { [weak self] in
            let stream = NotificationCenter.default.notifications(
                named: .aiForensicModeEnabled
            )
            for await _ in stream {
                await MainActor.run { self?.cancelInFlight() }
            }
        }
        // Warm the on-device model so the first tap is fast.
        Task.detached(priority: .background) { [prewarmBrain] in
            await prewarmBrain.prewarm()
        }
    }

    deinit { forensicObserverTask?.cancel() }

    // MARK: - Public

    func askForCoaching(scene: SceneSummary, imageJPEG: Data? = nil) {
        startWork { service, router in
            await router.coachingAdvice(scene: scene, imageJPEG: imageJPEG) { partial in
                await MainActor.run { service.partialText = partial }
            }
        }
    }

    func askForScoreExplanation(score: PhotoScore,
                                scene: SceneSummary,
                                imageJPEG: Data? = nil) {
        startWork { service, router in
            await router.scoreExplanation(score: score,
                                          scene: scene,
                                          imageJPEG: imageJPEG) { partial in
                await MainActor.run { service.partialText = partial }
            }
        }
    }

    func askForCaption(image: UIImage, mode: CaptureMode) {
        guard let data = image.jpegData(compressionQuality: 0.7) else { return }
        startWork { _, router in
            await router.photoCaption(imageJPEG: data, mode: mode)
        }
    }

    func clear() {
        cancelInFlight()
        lastResponse = nil
        partialText = ""
        lastError = nil
    }

    // MARK: - Internals

    private func startWork(
        _ work: @escaping @Sendable (AICoachService, AIRouter) async -> AIResponse
    ) {
        cancelInFlight()
        isWorking = true
        lastError = nil
        partialText = ""
        let snapshot = AISettingsSnapshot(settings)
        currentTask = Task { @MainActor [weak self] in
            guard let self else { return }
            let router = AIRouter(settings: snapshot)
            let response = await work(self, router)
            guard !Task.isCancelled else { return }
            self.lastResponse = response
            self.partialText = ""
            self.isWorking = false
        }
    }

    private func cancelInFlight() {
        currentTask?.cancel()
        currentTask = nil
        isWorking = false
        partialText = ""
    }
}
