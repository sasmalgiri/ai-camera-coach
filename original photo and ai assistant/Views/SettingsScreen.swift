//
//  SettingsScreen.swift
//  AI Camera Coach
//

import AVFoundation
import SwiftUI

struct SettingsScreen: View {
    @Binding var autoCorrection: Bool
    @Binding var flash: AVCaptureDevice.FlashMode
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Capture") {
                    Toggle("Auto Correction", isOn: $autoCorrection)
                    Picker("Flash", selection: $flash) {
                        Text("Auto").tag(AVCaptureDevice.FlashMode.auto)
                        Text("On").tag(AVCaptureDevice.FlashMode.on)
                        Text("Off").tag(AVCaptureDevice.FlashMode.off)
                    }
                }
                Section("About") {
                    LabeledContent("App", value: "AI Camera Coach")
                    LabeledContent("Version", value: "1.0")
                    LabeledContent("Price", value: "$4.99 · One-time")
                }
                Section("Privacy") {
                    Text("All processing happens on your device. No account, no ads, no tracking.")
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
        }
    }
}
