//
//  AICoachInsightSheet.swift
//  AI Camera Coach
//
//  Surface for the AI Expert's response. Always shows a disclaimer banner
//  above the body and a provenance badge below it.
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
                        if service.isWorking {
                            HStack(spacing: 10) {
                                ProgressView()
                                Text("Thinking…").foregroundStyle(.secondary)
                            }
                        } else if let response = service.lastResponse {
                            Text(response.text)
                                .font(.body)
                                .foregroundStyle(.primary)
                                .multilineTextAlignment(.leading)
                            AIProvenanceView(provenance: response.provenance)
                        } else if let err = service.lastError {
                            Text(err)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("No insight yet.")
                                .foregroundStyle(.secondary)
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
