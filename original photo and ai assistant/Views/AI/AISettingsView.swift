//
//  AISettingsView.swift
//  AI Camera Coach
//
//  Full UI for the AI Expert: toggles for cloud AI, per-provider key
//  entry, model selection, the Forensic Mode kill switch, and the
//  first-time consent alert that must clear before any cloud call.
//

import SwiftUI

struct AISettingsView: View {
    @Bindable var settings: AISettingsStore
    @State private var showConsent = false
    @State private var pendingToggle = false

    var body: some View {
        Form {

            Section {
                Toggle("Forensic Mode (block all cloud AI)",
                       isOn: $settings.forensicMode)
                    .tint(.red)
                Text("When on, the app uses only on-device AI. Any cloud call in flight is cancelled immediately.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Kill switch")
            }

            Section {
                Toggle(isOn: Binding(
                    get: { settings.cloudAIEnabled },
                    set: { newValue in
                        if newValue && !settings.hasConsentedToCloud {
                            // Require consent before flipping on.
                            pendingToggle = true
                            showConsent = true
                        } else {
                            settings.cloudAIEnabled = newValue
                        }
                    }
                )) {
                    Text("Enable Cloud AI")
                }
                .disabled(settings.forensicMode)

                Picker("Preferred provider", selection: $settings.preferredProvider) {
                    ForEach(AISettingsStore.CloudProviderChoice.allCases) { p in
                        Text(p.displayName).tag(p)
                    }
                }
                .disabled(!settings.cloudAIEnabled || settings.forensicMode)
            } header: {
                Text("Cloud AI")
            } footer: {
                Text("Cloud AI uses your own API key. The app never proxies through a developer key. By default everything runs on-device.")
            }

            Section("OpenAI") {
                SecureField("API key (sk-…)", text: $settings.openAIKey)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                TextField("Model", text: $settings.openAIModel)
                    .autocorrectionDisabled()
            }

            Section("Anthropic") {
                SecureField("API key (sk-ant-…)", text: $settings.anthropicKey)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                TextField("Model", text: $settings.anthropicModel)
                    .autocorrectionDisabled()
            }

            Section {
                Button(role: .destructive) {
                    settings.clearAllKeys()
                } label: {
                    Label("Clear all API keys", systemImage: "trash")
                }
            } footer: {
                Text("Keys are stored only on this device, in the iOS Keychain. They never sync to iCloud Keychain.")
            }
        }
        .navigationTitle("AI Expert")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Send to cloud AI?",
               isPresented: $showConsent,
               actions: {
            Button("Cancel", role: .cancel) {
                pendingToggle = false
            }
            Button("I understand") {
                if pendingToggle {
                    settings.hasConsentedToCloud = true
                    settings.cloudAIEnabled = true
                }
                pendingToggle = false
            }
        }, message: {
            Text("Cloud AI sends a small description of your scene to your chosen provider (OpenAI or Anthropic) using your own API key. No image or audio is sent without your action. You can turn this off any time.")
        })
    }
}
