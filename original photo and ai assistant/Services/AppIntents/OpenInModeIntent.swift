//
//  OpenInModeIntent.swift
//  AI Camera Coach
//
//  Lets users say "Hey Siri, open AI Camera Coach in Pet mode" or pick
//  a mode from the Shortcuts app. Opens the app and pre-selects the
//  requested mode via UserDefaults — the camera reads it on launch.
//

import AppIntents
import Foundation

nonisolated enum CaptureModeAppEnum: String, AppEnum {
    case original, smart, family, child, pet, travel

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Capture Mode"
    static let caseDisplayRepresentations: [CaptureModeAppEnum: DisplayRepresentation] = [
        .original: "Original",
        .smart: "Smart",
        .family: "Family",
        .child: "Child",
        .pet: "Pet",
        .travel: "Travel"
    ]

    var captureMode: CaptureMode {
        CaptureMode(rawValue: rawValue) ?? .smart
    }
}

struct OpenInModeIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Camera in Mode"
    static let description = IntentDescription(
        "Opens AI Camera Coach in the chosen capture mode."
    )
    static let openAppWhenRun: Bool = true

    @Parameter(title: "Mode")
    var mode: CaptureModeAppEnum

    func perform() async throws -> some IntentResult {
        UserDefaults.standard.set(mode.rawValue, forKey: "camera.requestedMode")
        return .result()
    }
}

struct AICameraCoachShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: OpenInModeIntent(),
            phrases: [
                "Open \(.applicationName) in \(\.$mode) mode",
                "Start \(.applicationName) for \(\.$mode)"
            ],
            shortTitle: "Open in Mode",
            systemImageName: "camera.aperture"
        )
    }
}
