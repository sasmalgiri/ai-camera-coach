//
//  SettingsScreen.swift
//  AI Camera Coach
//

import AVFoundation
import SwiftUI

struct SettingsScreen: View {
    @Binding var autoCorrection: Bool
    @Binding var flash: AVCaptureDevice.FlashMode
    @Bindable var aiSettings: AISettingsStore
    @Environment(\.dismiss) private var dismiss
    @State private var showHelp = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button {
                        showHelp = true
                    } label: {
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
                } header: {
                    Text("Capture")
                } footer: {
                    Text("Auto Correction quietly improves exposure, white balance and color on saved photos. Original mode always ignores this and saves the raw frame.")
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

                Section("About") {
                    LabeledContent("App", value: "AI Camera Coach")
                    LabeledContent("Version", value: "1.0")
                    LabeledContent("Price", value: "$4.99 · One-time")
                }
                Section("Privacy") {
                    Text("All scene analysis runs on your device. Cloud AI is opt-in and uses your own API key. No accounts. No ads. No tracking.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
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
