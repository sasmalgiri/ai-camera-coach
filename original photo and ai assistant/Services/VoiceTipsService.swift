//
//  VoiceTipsService.swift
//  AI Camera Coach
//
//  Optional spoken tips for hands-free shooting (tripod, selfie). Off by
//  default; toggle lives in Settings → Composition → Speak tips aloud.
//

import AVFoundation
import Foundation

@MainActor
final class VoiceTipsService {

    static let shared = VoiceTipsService()

    private let synth = AVSpeechSynthesizer()
    private var lastSpoken: String?
    private var lastSpokenAt: Date = .distantPast

    /// Speaks the tip only if it's new or it's been at least 8 s since the
    /// same line was last spoken. Keeps the app from nagging.
    func speak(_ text: String, language: String = "en-US") {
        guard UserDefaults.standard.bool(forKey: "camera.voiceTips") else { return }
        let now = Date()
        if text == lastSpoken, now.timeIntervalSince(lastSpokenAt) < 8 { return }
        lastSpoken = text
        lastSpokenAt = now
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: language)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.95
        utterance.preUtteranceDelay = 0.05
        synth.speak(utterance)
    }

    func stop() {
        synth.stopSpeaking(at: .immediate)
    }
}
