//
//  HapticsService.swift
//  AI Camera Coach
//
//  Lightweight wrapper around UIKit haptic generators. All calls are
//  no-ops on iPad if the device doesn't support haptics — the system
//  handles that quietly.
//

import UIKit

@MainActor
enum Haptics {

    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }

    static func selection() {
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }

    static func notify(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(type)
    }
}
