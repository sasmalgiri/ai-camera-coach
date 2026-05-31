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
    private(set) var isWorking: Bool = false
    private(set) var lastError: String?

    @ObservationIgnored private let settings: AISettingsStore
    @ObservationIgnored private var currentTask: Task<Void, Never>?
    @ObservationIgnored private var forensicObserverTask: Task<Void, Never>?

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
    }

    deinit { forensicObserverTask?.cancel() }

    // MARK: - Public

    func askForCoaching(scene: SceneSummary, imageJPEG: Data? = nil) {
        startWork { router in
            await router.coachingAdvice(scene: scene, imageJPEG: imageJPEG)
        }
    }

    func askForScoreExplanation(score: PhotoScore,
                                scene: SceneSummary,
                                imageJPEG: Data? = nil) {
        startWork { router in
            await router.scoreExplanation(score: score,
                                          scene: scene,
                                          imageJPEG: imageJPEG)
        }
    }

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
