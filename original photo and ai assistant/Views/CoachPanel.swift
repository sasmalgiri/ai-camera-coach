//
//  CoachPanel.swift
//  AI Camera Coach
//

import SwiftUI

struct CoachPanel: View {
    let score: Int
    let suggestions: [CoachSuggestion]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Photo Score")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.8))
                Spacer()
                Text("\(score)")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
            }
            ProgressView(value: Double(score) / 100.0)
                .tint(scoreColor)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(suggestions.prefix(3)) { s in
                    HStack(spacing: 10) {
                        Image(systemName: s.icon)
                            .font(.subheadline)
                            .frame(width: 22)
                            .foregroundStyle(.white)
                        Text(s.message)
                            .font(.subheadline)
                            .foregroundStyle(.white)
                        Spacer()
                    }
                }
            }
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
            .stroke(.white.opacity(0.08), lineWidth: 1))
    }

    private var scoreColor: Color {
        switch score {
        case ..<40: return .red
        case ..<70: return .orange
        default: return .green
        }
    }
}
