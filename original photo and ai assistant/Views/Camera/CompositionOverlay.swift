//
//  CompositionOverlay.swift
//  AI Camera Coach
//
//  Optional overlays that sit on top of the camera preview:
//   · Rule-of-thirds grid
//   · Live horizon level indicator (uses DeviceLevelService)
//

import SwiftUI

struct CompositionOverlay: View {
    let showGrid: Bool
    let showLevel: Bool
    let rollDegrees: Double

    var body: some View {
        ZStack {
            if showGrid { RuleOfThirdsGrid() }
            if showLevel { HorizonLevel(rollDegrees: rollDegrees) }
        }
        .allowsHitTesting(false)
    }
}

private struct RuleOfThirdsGrid: View {
    var body: some View {
        GeometryReader { geo in
            Path { path in
                let w = geo.size.width
                let h = geo.size.height
                path.move(to: CGPoint(x: w / 3, y: 0))
                path.addLine(to: CGPoint(x: w / 3, y: h))
                path.move(to: CGPoint(x: 2 * w / 3, y: 0))
                path.addLine(to: CGPoint(x: 2 * w / 3, y: h))
                path.move(to: CGPoint(x: 0, y: h / 3))
                path.addLine(to: CGPoint(x: w, y: h / 3))
                path.move(to: CGPoint(x: 0, y: 2 * h / 3))
                path.addLine(to: CGPoint(x: w, y: 2 * h / 3))
            }
            .stroke(.white.opacity(0.35), lineWidth: 0.6)
        }
    }
}

private struct HorizonLevel: View {
    let rollDegrees: Double

    private var isLevel: Bool { abs(rollDegrees) < 1.0 }

    var body: some View {
        GeometryReader { geo in
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let length = geo.size.width * 0.4
            ZStack {
                // Reference line (true horizontal).
                Path { p in
                    p.move(to: CGPoint(x: center.x - length / 2, y: center.y))
                    p.addLine(to: CGPoint(x: center.x + length / 2, y: center.y))
                }
                .stroke(.white.opacity(0.25), lineWidth: 1)

                // Rotating line — turns green when level.
                Path { p in
                    p.move(to: CGPoint(x: center.x - length / 2, y: center.y))
                    p.addLine(to: CGPoint(x: center.x + length / 2, y: center.y))
                }
                .stroke(isLevel ? .green : .yellow, lineWidth: 2)
                .rotationEffect(.degrees(-rollDegrees), anchor: .center)
                .animation(.easeOut(duration: 0.12), value: rollDegrees)
            }
        }
    }
}
