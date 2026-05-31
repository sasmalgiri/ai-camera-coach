//
//  OnboardingView.swift
//  AI Camera Coach
//
//  Shown the first time the app launches, and on demand from Settings.
//  Five short pages that teach the core concepts without jargon.
//

import SwiftUI

struct OnboardingView: View {

    let onFinish: () -> Void
    @State private var page = 0

    private let pages: [OnboardingPage] = OnboardingPage.all

    var body: some View {
        ZStack {
            LinearGradient(colors: [.black, Color(red: 0.05, green: 0.07, blue: 0.12)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button("Skip") { onFinish() }
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(.trailing, 18)
                }
                .padding(.top, 8)

                TabView(selection: $page) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { idx, p in
                        OnboardingPageView(page: p).tag(idx)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .always))

                Button {
                    advance()
                } label: {
                    Text(page == pages.count - 1 ? "Get started" : "Continue")
                        .font(.headline)
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(.white, in: Capsule())
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 28)
            }
        }
        .preferredColorScheme(.dark)
    }

    private func advance() {
        if page < pages.count - 1 {
            withAnimation { page += 1 }
        } else {
            onFinish()
        }
    }
}

// MARK: - Single page renderer

private struct OnboardingPageView: View {
    let page: OnboardingPage

    var body: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 0)
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: page.gradient,
                                         startPoint: .topLeading,
                                         endPoint: .bottomTrailing))
                    .frame(width: 130, height: 130)
                    .opacity(0.25)
                Image(systemName: page.symbol)
                    .font(.system(size: 56, weight: .semibold))
                    .foregroundStyle(.white)
            }
            Text(page.title)
                .font(.system(size: 28, weight: .bold))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)
                .padding(.horizontal, 28)
            Text(page.body)
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.78))
                .padding(.horizontal, 36)

            if !page.bullets.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(page.bullets, id: \.self) { bullet in
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.footnote)
                                .foregroundStyle(.green)
                            Text(bullet)
                                .font(.footnote)
                                .foregroundStyle(.white.opacity(0.8))
                        }
                    }
                }
                .padding(.top, 6)
                .padding(.horizontal, 36)
            }

            Spacer(minLength: 0)
        }
    }
}

// MARK: - Content

nonisolated struct OnboardingPage: Hashable {
    let symbol: String
    let title: String
    let body: String
    let bullets: [String]
    let gradient: [Color]

    static let all: [OnboardingPage] = [
        OnboardingPage(
            symbol: "sparkles",
            title: "Welcome to AI Camera Coach",
            body: "Take pro-looking photos without learning photography. The app handles the technical bits — you focus on the moment.",
            bullets: [],
            gradient: [.purple, .blue]
        ),
        OnboardingPage(
            symbol: "person.line.dotted.person",
            title: "Two AIs working for you",
            body: "An AI Coach gives you simple tips. An AI Photographer can capture for you when the moment looks right.",
            bullets: [
                "Coach: live tips like “move closer” or “wait for the smile”",
                "Photographer: tap once, it fires the shutter when confidence is high"
            ],
            gradient: [.blue, .cyan]
        ),
        OnboardingPage(
            symbol: "rectangle.3.group",
            title: "Pick a mode for the shot",
            body: "Modes change scoring and auto-capture rules. They don't change your raw photo unless you ask.",
            bullets: [
                "Original — raw camera, no enhancement",
                "Smart — balanced for everyday shots",
                "Family — waits for everyone's eyes open",
                "Child / Pet — tuned for movement and sharpness",
                "Travel — landmarks and level horizons"
            ],
            gradient: [.orange, .pink]
        ),
        OnboardingPage(
            symbol: "wand.and.stars",
            title: "The AI Expert (optional)",
            body: "Tap the ✨ button for natural-language insight from Apple Intelligence on your device. Want OpenAI or Anthropic instead? Paste your own key in Settings.",
            bullets: [
                "On-device first — no internet needed",
                "Cloud AI is opt-in and uses your own API key",
                "Every result shows where it came from"
            ],
            gradient: [.yellow, .orange]
        ),
        OnboardingPage(
            symbol: "lock.shield",
            title: "Private by default",
            body: "Everything runs on your iPhone. No accounts. No ads. No tracking. No cloud upload — unless you specifically turn cloud AI on.",
            bullets: [
                "Photos saved only to your device",
                "API keys stored in the iOS Keychain, this device only",
                "Forensic Mode disables every cloud call in one tap"
            ],
            gradient: [.green, .teal]
        )
    ]
}
