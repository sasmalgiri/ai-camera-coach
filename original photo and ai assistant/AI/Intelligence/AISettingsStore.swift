//
//  AISettingsStore.swift
//  AI Camera Coach — Intelligence layer
//
//  Observable user preferences governing the entire AI subsystem.
//  Persisted in UserDefaults; API keys themselves live in the Keychain.
//

import Foundation
import Observation

@Observable
@MainActor
final class AISettingsStore {

    enum CloudProviderChoice: String, CaseIterable, Sendable, Codable, Identifiable {
        case openAI, anthropic
        var id: String { rawValue }
        var displayName: String {
            switch self {
            case .openAI:    return "OpenAI"
            case .anthropic: return "Anthropic"
            }
        }
    }

    // MARK: - Persisted preferences

    var cloudAIEnabled: Bool {
        didSet { defaults.set(cloudAIEnabled, forKey: Keys.cloudEnabled) }
    }

    /// "Forensic mode" / kill switch — when on, ALL cloud calls are
    /// blocked at the router level. Survives app launches.
    var forensicMode: Bool {
        didSet {
            defaults.set(forensicMode, forKey: Keys.forensicMode)
            if forensicMode {
                // Cancel any in-flight cloud work the moment the switch
                // is thrown.
                NotificationCenter.default.post(name: .aiForensicModeEnabled, object: nil)
            }
        }
    }

    var preferredProvider: CloudProviderChoice {
        didSet { defaults.set(preferredProvider.rawValue, forKey: Keys.provider) }
    }

    var openAIModel: String {
        didSet { defaults.set(openAIModel, forKey: Keys.openAIModel) }
    }

    var anthropicModel: String {
        didSet { defaults.set(anthropicModel, forKey: Keys.anthropicModel) }
    }

    /// First-time consent — we must show the alert once before any cloud
    /// call goes out, even if a key is already saved.
    var hasConsentedToCloud: Bool {
        didSet { defaults.set(hasConsentedToCloud, forKey: Keys.consented) }
    }

    // MARK: - Keychain (mirrored for the UI; truth lives in Keychain)

    var openAIKey: String {
        didSet {
            if openAIKey.isEmpty {
                AIKeychainStore.delete(for: .openAI)
            } else {
                AIKeychainStore.save(openAIKey, for: .openAI)
            }
        }
    }

    var anthropicKey: String {
        didSet {
            if anthropicKey.isEmpty {
                AIKeychainStore.delete(for: .anthropic)
            } else {
                AIKeychainStore.save(anthropicKey, for: .anthropic)
            }
        }
    }

    // MARK: - Init

    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.cloudAIEnabled = defaults.bool(forKey: Keys.cloudEnabled)
        self.forensicMode = defaults.bool(forKey: Keys.forensicMode)
        let providerRaw = defaults.string(forKey: Keys.provider) ?? CloudProviderChoice.openAI.rawValue
        self.preferredProvider = CloudProviderChoice(rawValue: providerRaw) ?? .openAI
        self.openAIModel = defaults.string(forKey: Keys.openAIModel) ?? "gpt-4o-mini"
        self.anthropicModel = defaults.string(forKey: Keys.anthropicModel) ?? "claude-haiku-4-5"
        self.hasConsentedToCloud = defaults.bool(forKey: Keys.consented)
        self.openAIKey = AIKeychainStore.load(for: .openAI) ?? ""
        self.anthropicKey = AIKeychainStore.load(for: .anthropic) ?? ""
    }

    // MARK: - Helpers

    /// Final gate the router uses to allow a cloud call.
    var cloudCallsAllowed: Bool {
        cloudAIEnabled && !forensicMode && hasConsentedToCloud
    }

    func clearAllKeys() {
        openAIKey = ""
        anthropicKey = ""
    }

    private enum Keys {
        static let cloudEnabled = "ai.settings.cloudEnabled"
        static let forensicMode = "ai.settings.forensicMode"
        static let provider = "ai.settings.provider"
        static let openAIModel = "ai.settings.openAIModel"
        static let anthropicModel = "ai.settings.anthropicModel"
        static let consented = "ai.settings.consented"
    }
}

extension Notification.Name {
    static let aiForensicModeEnabled = Notification.Name("ai.forensicModeEnabled")
}
