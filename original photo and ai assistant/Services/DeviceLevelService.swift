//
//  DeviceLevelService.swift
//  AI Camera Coach
//
//  Reads gravity vector from CoreMotion to expose live device-roll angle
//  for the on-screen horizon level overlay.
//

import CoreMotion
import Foundation
import Observation

@Observable
@MainActor
final class DeviceLevelService {

    /// Device roll in degrees. 0 = perfectly level (portrait, top up).
    /// Positive = right side down, negative = left side down.
    private(set) var rollDegrees: Double = 0

    @ObservationIgnored private let manager = CMMotionManager()

    func start() {
        guard manager.isDeviceMotionAvailable, !manager.isDeviceMotionActive else { return }
        manager.deviceMotionUpdateInterval = 1.0 / 30.0
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self, let motion else { return }
            let g = motion.gravity
            // Roll around the device's long axis (portrait orientation).
            let radians = atan2(g.x, -g.y)
            self.rollDegrees = radians * 180 / .pi
        }
    }

    func stop() {
        if manager.isDeviceMotionActive { manager.stopDeviceMotionUpdates() }
    }
}
