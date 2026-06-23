//
//  HelpSheet.swift
//  AI Camera Coach
//
//  Reference card shown from the camera "?" button or Settings.
//  Compact, scrollable, no jargon.
//

import SwiftUI

struct HelpSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showReplayOnboarding = false

    var body: some View {
        NavigationStack {
            List {
                Section("How to use the camera") {
                    HelpRow(symbol: "camera.viewfinder",
                            title: "Point and shoot",
                            text: "The big white circle is the shutter. Tap to capture.")
                    HelpRow(symbol: "wand.and.stars.inverse",
                            title: "AI Photographer",
                            text: "Tap the wand to let the app decide when to fire — it waits for sharp focus, open eyes, and good light.")
                    HelpRow(symbol: "AI",
                            isText: true,
                            title: "Show the Coach",
                            text: "The “AI” pill toggles the live Photo Score (0–100) and short coaching tips.")
                    HelpRow(symbol: "sparkles",
                            title: "Ask the AI Expert",
                            text: "Tap ✨ for a natural-language explanation from Apple Intelligence — or your own OpenAI/Anthropic key if you've added one.")
                    HelpRow(symbol: "photo.stack",
                            title: "Gallery",
                            text: "Open saved photos. Long-press a photo in detail view to compare with the original.")
                    HelpRow(symbol: "arrow.up.left.and.arrow.down.right",
                            title: "Guide Me (minimum-word mode)",
                            text: "Replaces written tips with arrows and corner icons around the edges. Arrows pulse where you should adjust; corner icons cover light, eyes, level, and ready. Center stays clear so you can see the scene.")
                }

                Section {
                    ForEach(CaptureMode.allCases) { mode in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: mode.symbolName)
                                .font(.title3)
                                .frame(width: 28)
                                .foregroundStyle(.tint)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(mode.title).font(.body.weight(.semibold))
                                Text(mode.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                } header: {
                    Text("What each mode does")
                } footer: {
                    Text("Modes change the score weights and the auto-capture rules. They never alter your raw photo — that's controlled by Auto Correction and Original mode.")
                }

                Section("Privacy") {
                    Text("All scene analysis runs on your iPhone. Cloud AI is opt-in and uses your own API key. Forensic Mode disables every cloud call in one tap.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section {
                    Button {
                        showReplayOnboarding = true
                    } label: {
                        Label("Replay tutorial", systemImage: "play.rectangle")
                    }
                }
            }
            .navigationTitle("How it works")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .fullScreenCover(isPresented: $showReplayOnboarding) {
                OnboardingView(onFinish: { showReplayOnboarding = false })
            }
        }
    }
}

private struct HelpRow: View {
    let symbol: String
    var isText: Bool = false
    let title: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Group {
                if isText {
                    Text(symbol)
                        .font(.caption.bold())
                        .foregroundStyle(.black)
                        .frame(width: 28, height: 20)
                        .background(.white, in: Capsule())
                } else {
                    Image(systemName: symbol)
                        .font(.title3)
                        .foregroundStyle(.tint)
                        .frame(width: 28)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.body.weight(.semibold))
                Text(text)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}
