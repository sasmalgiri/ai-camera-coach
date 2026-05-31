//
//  ModePicker.swift
//  AI Camera Coach
//

import SwiftUI

struct ModePicker: View {
    @Binding var selected: CaptureMode
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(CaptureMode.allCases) { mode in
                        Button {
                            selected = mode
                            dismiss()
                        } label: {
                            HStack(spacing: 14) {
                                Image(systemName: mode.symbolName)
                                    .font(.title3)
                                    .frame(width: 36, height: 36)
                                    .background(Color.accentColor.opacity(0.15),
                                                in: RoundedRectangle(cornerRadius: 10))
                                    .foregroundStyle(.tint)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(mode.title)
                                        .font(.body.weight(.semibold))
                                        .foregroundStyle(.primary)
                                    Text(mode.subtitle)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if mode == selected {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.tint)
                                }
                            }
                        }
                    }
                } footer: {
                    Text("Modes change how the coach scores your photo and when the AI Photographer auto-captures. They don't change your raw photo unless Auto Correction is on. Original always saves the unedited frame.")
                }
            }
            .navigationTitle("Choose Mode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
