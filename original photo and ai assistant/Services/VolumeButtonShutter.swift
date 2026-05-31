//
//  VolumeButtonShutter.swift
//  AI Camera Coach
//
//  Listens for hardware volume button presses while the camera is active
//  and fires the shutter. Uses AVAudioSession.outputVolume KVO — the
//  documented, non-private-API technique.
//

import AVFoundation
import Foundation

@MainActor
final class VolumeButtonShutter: NSObject {

    private let session = AVAudioSession.sharedInstance()
    private var observation: NSKeyValueObservation?
    private var lastVolume: Float?
    private var onTrigger: (() -> Void)?

    /// Starts listening. The trigger is called for any volume change
    /// (up OR down) while listening.
    func start(onTrigger: @escaping () -> Void) {
        self.onTrigger = onTrigger
        do {
            try session.setCategory(.ambient,
                                    mode: .default,
                                    options: [.mixWithOthers])
            try session.setActive(true, options: [])
        } catch {
            return
        }
        lastVolume = session.outputVolume
        observation = session.observe(\.outputVolume, options: [.new]) { [weak self] _, change in
            Task { @MainActor [weak self] in
                guard let self,
                      let new = change.newValue,
                      let last = self.lastVolume else { return }
                if abs(new - last) > 0.0001 {
                    self.lastVolume = new
                    self.onTrigger?()
                }
            }
        }
    }

    func stop() {
        observation?.invalidate()
        observation = nil
        onTrigger = nil
        try? session.setActive(false, options: [.notifyOthersOnDeactivation])
    }
}
