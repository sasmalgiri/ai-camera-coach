//
//  GuideMeOverlay.swift
//  AI Camera Coach
//
//  Edge-and-corner only guidance for users who don't read English fluently
//  or who want minimum-word, glyph-driven coaching. The center of the
//  preview is never covered — the user can always see the scene.
//
//  Layout:
//
//      [TL glyph]   [   top arrow   ]   [TR glyph]
//                  ─────────────────────
//      [L arrow]      (camera preview)      [R arrow]
//                  ─────────────────────
//      [BL glyph]   [  bottom arrow ]   [BR glyph]
//
//  Each arrow / glyph has three states (idle, prompt, done) and pulses
//  yellow while a prompt is active, settles to green when satisfied.
//

import SwiftUI

// MARK: - State

nonisolated struct GuideMeState: Sendable, Equatable {

    enum Status: Sendable {
        case idle    // not relevant right now (hidden)
        case prompt  // user needs to act (pulsing yellow)
        case done    // good — show green check briefly
    }

    /// "Move/tilt camera in this direction." Bound to subject-position fix.
    var leftArrow: Status = .idle
    var rightArrow: Status = .idle
    var topArrow: Status = .idle
    var bottomArrow: Status = .idle

    /// Corner glyphs — non-positional state.
    var lightGlyph: Status = .idle   // top-left  — sun
    var eyesGlyph: Status = .idle    // top-right — eye
    var levelGlyph: Status = .idle   // bottom-left — level
    var readyGlyph: Status = .idle   // bottom-right — checkmark seal

    /// True when everything is green and the photo is ready.
    var allReady: Bool {
        leftArrow != .prompt && rightArrow != .prompt
        && topArrow != .prompt && bottomArrow != .prompt
        && lightGlyph != .prompt && eyesGlyph != .prompt
        && levelGlyph != .prompt
    }

    /// Translate scene analysis + score into the glyph state.
    static func make(from analysis: SceneAnalysis,
                     score: PhotoScore,
                     rollDegrees: Double,
                     mode: CaptureMode) -> GuideMeState {
        var s = GuideMeState()

        // Subject framing — only meaningful when there's a face.
        if let face = analysis.faces.first {
            let cx = face.boundingBox.midX
            let cy = face.boundingBox.midY
            if cx < 0.30 { s.leftArrow = .prompt }
            else if cx > 0.70 { s.rightArrow = .prompt }
            if cy < 0.30 { s.bottomArrow = .prompt }
            else if cy > 0.70 { s.topArrow = .prompt }
        } else if mode != .travel {
            // No subject — central reticle stays implicit; show all four
            // arrows briefly to suggest "frame your subject".
            s.leftArrow = .prompt
            s.rightArrow = .prompt
        }

        // Light.
        if analysis.brightness < 0.25 { s.lightGlyph = .prompt }
        else if analysis.brightness > 0.85 { s.lightGlyph = .prompt }
        else if analysis.brightness > 0.35 { s.lightGlyph = .done }

        // Eyes (Family / Child / Smart with faces).
        if analysis.faceCount > 0 {
            let openCount = analysis.faces.filter { $0.eyesOpenConfidence > 0.55 }.count
            let ratio = Double(openCount) / Double(analysis.faceCount)
            if ratio < 0.7 { s.eyesGlyph = .prompt }
            else { s.eyesGlyph = .done }
        }

        // Level — surface only when tilt is meaningful for the mode.
        if mode == .travel || mode == .smart {
            if abs(rollDegrees) > 2.5 { s.levelGlyph = .prompt }
            else { s.levelGlyph = .done }
        }

        // Ready badge.
        if score.total >= 75 && s.allReady {
            s.readyGlyph = .done
        }

        return s
    }
}

// MARK: - Overlay view

struct GuideMeOverlay: View {
    let state: GuideMeState

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Edge arrows — pulse inward toward the centre.
                EdgeArrow(direction: .left,  status: state.leftArrow)
                    .position(x: 28, y: geo.size.height / 2)
                EdgeArrow(direction: .right, status: state.rightArrow)
                    .position(x: geo.size.width - 28, y: geo.size.height / 2)
                EdgeArrow(direction: .up,    status: state.topArrow)
                    .position(x: geo.size.width / 2, y: 28)
                EdgeArrow(direction: .down,  status: state.bottomArrow)
                    .position(x: geo.size.width / 2, y: geo.size.height - 28)

                // Corner glyphs.
                CornerGlyph(symbol: "sun.max.fill",     status: state.lightGlyph)
                    .position(x: 28, y: 28)
                CornerGlyph(symbol: "eye.fill",         status: state.eyesGlyph)
                    .position(x: geo.size.width - 28, y: 28)
                CornerGlyph(symbol: "level.fill",       status: state.levelGlyph)
                    .position(x: 28, y: geo.size.height - 28)
                CornerGlyph(symbol: "checkmark.seal.fill", status: state.readyGlyph)
                    .position(x: geo.size.width - 28, y: geo.size.height - 28)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(false)
        .accessibilityLabel(accessibilitySummary)
    }

    /// VoiceOver fallback — describes the active prompts in words.
    private var accessibilitySummary: String {
        var parts: [String] = []
        if state.leftArrow == .prompt { parts.append("Subject is on the left, recenter.") }
        if state.rightArrow == .prompt { parts.append("Subject is on the right, recenter.") }
        if state.topArrow == .prompt { parts.append("Subject is high, tilt down or recenter.") }
        if state.bottomArrow == .prompt { parts.append("Subject is low, tilt up or recenter.") }
        if state.lightGlyph == .prompt { parts.append("Light needs adjusting.") }
        if state.eyesGlyph == .prompt { parts.append("Wait for eyes to open.") }
        if state.levelGlyph == .prompt { parts.append("Level the horizon.") }
        if state.readyGlyph == .done { parts.append("Ready to capture.") }
        return parts.isEmpty ? "Scene looks good." : parts.joined(separator: " ")
    }
}

// MARK: - Pieces

private enum ArrowDirection { case up, down, left, right }

private struct EdgeArrow: View {
    let direction: ArrowDirection
    let status: GuideMeState.Status

    @State private var pulse = false

    var body: some View {
        Group {
            if status != .idle {
                Image(systemName: arrowSymbol)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(tint)
                    .padding(10)
                    .background(.black.opacity(0.45), in: Circle())
                    .scaleEffect(status == .prompt && pulse ? 1.1 : 1.0)
                    .opacity(status == .prompt && pulse ? 1.0 : 0.65)
                    .shadow(color: tint.opacity(0.5), radius: 6)
                    .onAppear {
                        if status == .prompt {
                            withAnimation(.easeInOut(duration: 0.6).repeatForever()) {
                                pulse = true
                            }
                        }
                    }
                    .transition(.opacity)
            }
        }
    }

    private var arrowSymbol: String {
        switch direction {
        case .up:    return "arrow.up"
        case .down:  return "arrow.down"
        case .left:  return "arrow.left"
        case .right: return "arrow.right"
        }
    }

    private var tint: Color {
        switch status {
        case .idle:   return .clear
        case .prompt: return .yellow
        case .done:   return .green
        }
    }
}

private struct CornerGlyph: View {
    let symbol: String
    let status: GuideMeState.Status

    @State private var pulse = false

    var body: some View {
        Group {
            if status != .idle {
                Image(systemName: symbol)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(tint)
                    .padding(8)
                    .background(.black.opacity(0.45), in: Circle())
                    .scaleEffect(status == .prompt && pulse ? 1.12 : 1.0)
                    .onAppear {
                        if status == .prompt {
                            withAnimation(.easeInOut(duration: 0.7).repeatForever()) {
                                pulse = true
                            }
                        }
                    }
                    .transition(.opacity)
            }
        }
    }

    private var tint: Color {
        switch status {
        case .idle:   return .clear
        case .prompt: return .yellow
        case .done:   return .green
        }
    }
}
