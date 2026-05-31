//
//  NLPExpert.swift
//  AI Camera Coach — MoE layer
//
//  Pulls language signals out of the OCR snippets (or classification
//  labels) using NaturalLanguage on-device.
//

import Foundation
import NaturalLanguage

nonisolated enum NLPExpert {

    /// Builds an NLPFinding from text the vision side already extracted.
    /// Pure on-device, no model loading beyond NaturalLanguage's defaults.
    static func analyze(text: String) -> NLPFinding? {
        guard !text.isEmpty else { return nil }

        // Language identification.
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        let language = recognizer.dominantLanguage.map { $0.rawValue }

        // Keyword-ish extraction via lemma + noun filter.
        var keywords: Set<String> = []
        let tagger = NLTagger(tagSchemes: [.lemma, .lexicalClass])
        tagger.string = text
        let options: NLTagger.Options = [.omitPunctuation, .omitWhitespace, .joinNames]
        tagger.enumerateTags(in: text.startIndex..<text.endIndex,
                             unit: .word,
                             scheme: .lexicalClass,
                             options: options) { tag, range in
            if let tag, tag == .noun || tag == .placeName || tag == .organizationName || tag == .personalName {
                let token = String(text[range]).lowercased()
                if token.count >= 3 { keywords.insert(token) }
            }
            return true
        }

        let sortedKeywords = Array(keywords).sorted().prefix(6)
        return NLPFinding(keywords: Array(sortedKeywords),
                          dominantLanguage: language)
    }
}
