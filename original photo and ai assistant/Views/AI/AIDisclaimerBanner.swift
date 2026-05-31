//
//  AIDisclaimerBanner.swift
//  AI Camera Coach
//

import SwiftUI

struct AIDisclaimerBanner: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.bubble")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.yellow)
            Text("AI suggestions can be wrong. Use your own judgment.")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.85))
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(.yellow.opacity(0.35), lineWidth: 1)
        )
    }
}
