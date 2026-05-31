//
//  SettingsScreen.swift
//  AI Camera Coach
//

import AVFoundation
import SwiftUI

struct SettingsScreen: View {
    @Binding var autoCorrection: Bool
    @Binding var flash: AVCaptureDevice.FlashMode
    @Binding var showGrid: Bool
    @Binding var showLevel: Bool
    @Binding var saveToPhotos: Bool
    @Bindable var aiSettings: AISettingsStore
    @Environment(\.dismiss) private var dismiss
    @State private var showHelp = false

    @AppStorage("camera.voiceTips") private var voiceTips: Bool = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button { showHelp = true } label: {
                        Label("How it works", systemImage: "questionmark.circle")
                    }
                } footer: {
                    Text("A quick reference for every button and mode, plus the option to replay the welcome tutorial.")
                }

                Section {
                    Toggle("Auto Correction", isOn: $autoCorrection)
                    Picker("Flash", selection: $flash) {
                        Text("Auto").tag(AVCaptureDevice.FlashMode.auto)
                        Text("On").tag(AVCaptureDevice.FlashMode.on)
                        Text("Off").tag(AVCaptureDevice.FlashMode.off)
                    }
                    Toggle("Save to Photos library", isOn: $saveToPhotos)
                } header: {
                    Text("Capture")
                } footer: {
                    Text("Auto Correction quietly improves exposure, white balance and color on saved photos. Original mode always ignores this. Saved to Photos library writes a copy to your iOS Photos so the rest of your apps can see them.")
                }

                Section {
                    Toggle("Rule-of-thirds grid", isOn: $showGrid)
                    Toggle("Horizon level", isOn: $showLevel)
                    Toggle("Speak tips aloud", isOn: $voiceTips)
                } header: {
                    Text("Composition")
                } footer: {
                    Text("Overlays sit on top of the preview only — they're not baked into your saved photo.")
                }

                Section("AI Expert") {
                    NavigationLink {
                        AISettingsView(settings: aiSettings)
                    } label: {
                        Label("Configure AI Expert", systemImage: "sparkles")
                    }
                    Text(aiStatusLine)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section {
                    NavigationLink {
                        PrivacyPromiseView()
                    } label: {
                        Label("Our privacy promise", systemImage: "lock.shield")
                    }
                } header: {
                    Text("Privacy")
                }

                Section("About") {
                    LabeledContent("App", value: "AI Camera Coach")
                    LabeledContent("Version", value: "2.0")
                    LabeledContent("Price", value: "$4.99 · One-time")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showHelp) { HelpSheet() }
        }
    }

    private var aiStatusLine: String {
        if aiSettings.forensicMode {
            return "Forensic Mode is on — only on-device AI will be used."
        }
        if aiSettings.cloudAIEnabled {
            return "Cloud AI enabled (\(aiSettings.preferredProvider.displayName)) using your own key."
        }
        return "On-device AI only. Cloud AI is off."
    }
}

// MARK: - Privacy promise page

struct PrivacyPromiseView: View {
    var body: some View {
        List {
            Section("What we do") {
                Row(icon: "iphone", title: "All processing on your device",
                    text: "Vision face/scene/text analysis, scoring, coaching tips — all run on your iPhone.")
                Row(icon: "lock.fill", title: "Keychain-only API keys",
                    text: "If you add an OpenAI or Anthropic key, it's stored in the iOS Keychain on THIS device only — never iCloud Keychain.")
                Row(icon: "hand.raised.fill", title: "Kill switch",
                    text: "Forensic Mode disables every cloud call in one tap, and cancels anything in flight.")
                Row(icon: "tag", title: "Provenance on every output",
                    text: "Every AI result shows which engine produced it.")
            }
            Section("What we don't do") {
                Row(icon: "xmark.icloud", title: "No cloud upload by default",
                    text: "Nothing leaves your device until you explicitly turn Cloud AI on AND confirm the consent dialog.")
                Row(icon: "person.crop.circle.badge.xmark", title: "No account, no login",
                    text: "There is nothing to sign up for and nothing to forget.")
                Row(icon: "antenna.radiowaves.left.and.right.slash", title: "No analytics, no tracking, no ads",
                    text: "We don't ship third-party SDKs. We don't phone home. We don't sell anything.")
                Row(icon: "shippingbox.fill", title: "No developer-managed API keys",
                    text: "If you use cloud AI, it's billed to your own provider account. The app never proxies through us.")
            }
        }
        .navigationTitle("Privacy")
        .navigationBarTitleDisplayMode(.inline)
    }

    private struct Row: View {
        let icon: String
        let title: String
        let text: String
        var body: some View {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                    .frame(width: 28)
                    .foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.body.weight(.semibold))
                    Text(text).font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 2)
        }
    }
}
