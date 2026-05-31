//
//  AICoachInsightSheet.swift
//  AI Camera Coach
//

import SwiftUI

struct AICoachInsightSheet: View {
    @Bindable var service: AICoachService
    let onClose: () -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                AIDisclaimerBanner()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if let response = service.lastResponse {
                            Text(response.text)
                                .font(.body)
                                .foregroundStyle(.primary)
                                .multilineTextAlignment(.leading)
                                .textSelection(.enabled)
                            AIProvenanceView(provenance: response.provenance)
                        } else if !service.partialText.isEmpty {
                            // Live streaming text.
                            VStack(alignment: .leading, spacing: 10) {
                                Text(service.partialText)
                                    .font(.body)
                                    .foregroundStyle(.primary)
                                    .multilineTextAlignment(.leading)
                                StreamingIndicator()
                            }
                        } else if service.isWorking {
                            HStack(spacing: 10) {
                                ProgressView()
                                Text("Analysing scene…")
                                    .foregroundStyle(.secondary)
                            }
                        } else if let err = service.lastError {
                            Text(err).foregroundStyle(.secondary)
                        } else {
                            Text("No insight yet.").foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                Spacer(minLength: 0)
            }
            .padding()
            .navigationTitle("AI Expert")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { onClose() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

private struct StreamingIndicator: View {
    @State private var pulse = false
    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<3) { i in
                Circle()
                    .fill(.tint)
                    .frame(width: 6, height: 6)
                    .opacity(pulse ? 1 : 0.3)
                    .animation(
                        .easeInOut(duration: 0.7)
                        .repeatForever()
                        .delay(Double(i) * 0.18),
                        value: pulse
                    )
            }
        }
        .onAppear { pulse = true }
    }
}
