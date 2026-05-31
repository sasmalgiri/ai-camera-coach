//
//  ParallelAppleBrain.swift
//  AI Camera Coach — MoE layer
//

import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

actor ParallelAppleBrain {

    private let synthInstructions = """
    You are a warm, concise photography coach. Speak in plain language.
    Never use technical terms like ISO, EV, aperture, shutter speed,
    histograms, or dynamic range. Never recommend changing lenses, gear,
    or apps. Each tip MUST reference a concrete fact from the analysis.
    Maximum three short imperative sentences. Be encouraging.
    """

    /// Optional callback used to deliver streaming partial tokens to the
    /// UI. Set before calling `synthesize`. Ignored by the non-streaming
    /// map step (we only stream the final reduce).
    var onPartial: (@Sendable (String) async -> Void)?

    func setOnPartial(_ handler: (@Sendable (String) async -> Void)?) {
        self.onPartial = handler
    }

    func isAvailable() async -> Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) {
            return SystemLanguageModel.default.availability == .available
        }
        #endif
        return false
    }

    /// Prewarm the on-device model so the first AI Expert tap is snappy.
    func prewarm() async {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) {
            guard SystemLanguageModel.default.availability == .available else { return }
            let session = LanguageModelSession(instructions: synthInstructions)
            session.prewarm()
        }
        #endif
    }

    func synthesize(findings: ExpertFindings,
                    scene: SceneSummary) async -> String? {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) {
            return await runMapReduce(findings: findings, scene: scene)
        }
        #endif
        return nil
    }

    #if canImport(FoundationModels)

    @available(iOS 26.0, macOS 26.0, *)
    private func runMapReduce(findings: ExpertFindings,
                              scene: SceneSummary) async -> String? {

        // Map — three parallel slices.
        async let peopleSummary = run(prompt: peoplePrompt(findings, scene))
        async let envSummary    = run(prompt: environmentPrompt(findings, scene))
        async let techSummary   = run(prompt: technicalPrompt(findings, scene))

        let (people, env, tech) = await (peopleSummary, envSummary, techSummary)
        if people == nil, env == nil, tech == nil { return nil }

        let reducePrompt = """
        You have three short summaries from specialist analyses of one
        photo. Combine them into up to three actionable tips for the
        photographer. Use plain language. Each tip MUST cite a concrete
        fact from the summaries (a face, a horizon angle, a sign, a
        detected animal, an attention region). Mode: \(scene.mode.title).

        People summary: \(people ?? "n/a")
        Environment summary: \(env ?? "n/a")
        Technical summary: \(tech ?? "n/a")
        """

        // Reduce — stream the final answer.
        return await runStreaming(prompt: reducePrompt)
    }

    @available(iOS 26.0, macOS 26.0, *)
    private func run(prompt: String) async -> String? {
        let session = LanguageModelSession(instructions: synthInstructions)
        do {
            let response = try await session.respond(to: prompt)
            let text = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? nil : text
        } catch {
            return nil
        }
    }

    /// Streams partial tokens to `onPartial` while accumulating the full
    /// final string.
    @available(iOS 26.0, macOS 26.0, *)
    private func runStreaming(prompt: String) async -> String? {
        let session = LanguageModelSession(instructions: synthInstructions)
        var accumulated = ""
        do {
            let stream = session.streamResponse(to: prompt)
            for try await partial in stream {
                accumulated = partial.content
                if let onPartial { await onPartial(accumulated) }
            }
            let text = accumulated.trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? nil : text
        } catch {
            // Fall back to non-streaming if streaming hits a guardrail/error.
            return await run(prompt: prompt)
        }
    }

    // MARK: - Prompts

    private func peoplePrompt(_ f: ExpertFindings, _ s: SceneSummary) -> String {
        var lines: [String] = []
        if let face = f.face { lines.append(face.promptText) }
        if let animal = f.animal { lines.append(animal.promptText) }
        if lines.isEmpty { lines.append("No people or animals detected.") }
        return """
        Summarise — in one sentence — what's notable about the subjects
        in this photo and any action the photographer should take about
        them. Mode: \(s.mode.title).

        \(lines.joined(separator: "\n"))
        """
    }

    private func environmentPrompt(_ f: ExpertFindings, _ s: SceneSummary) -> String {
        var lines: [String] = []
        if let cls = f.classification { lines.append(cls.promptText) }
        if let ocr = f.ocr { lines.append(ocr.promptText) }
        if let nlp = f.nlp { lines.append(nlp.promptText) }
        if let sal = f.saliency { lines.append(sal.promptText) }
        if lines.isEmpty { lines.append("Scene context unclear.") }
        return """
        Summarise — in one sentence — the scene's environment and any
        visual elements competing with the subject. Mode: \(s.mode.title).

        \(lines.joined(separator: "\n"))
        """
    }

    private func technicalPrompt(_ f: ExpertFindings, _ s: SceneSummary) -> String {
        var lines: [String] = ["Brightness: \(s.brightness.rawValue)",
                               "Sharpness: \(s.sharpness.rawValue)",
                               "Score: \(s.scoreTotal)/100"]
        if let horizon = f.horizon { lines.append(horizon.promptText) }
        if let aes = f.aesthetics { lines.append(aes.promptText) }
        return """
        Summarise — in one sentence — the technical quality of this
        photo (lighting, focus, level) and the single most important
        adjustment. Mode: \(s.mode.title).

        \(lines.joined(separator: "\n"))
        """
    }

    #endif
}
