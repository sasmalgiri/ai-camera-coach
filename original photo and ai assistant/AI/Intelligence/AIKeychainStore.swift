//
//  AIKeychainStore.swift
//  AI Camera Coach — Intelligence layer
//
//  Keychain wrapper for storing user-provided API keys with
//  .thisDeviceOnly access (keys never leave this device, even via iCloud
//  Keychain).
//

import Foundation
import Security

nonisolated enum AIKeychainStore {

    enum Provider: String, CaseIterable, Sendable {
        case openAI = "ai.camera.coach.openAI"
        case anthropic = "ai.camera.coach.anthropic"

        var displayName: String {
            switch self {
            case .openAI:    return "OpenAI"
            case .anthropic: return "Anthropic"
            }
        }
    }

    // MARK: - Save / Load / Delete

    @discardableResult
    static func save(_ key: String, for provider: Provider) -> Bool {
        guard let data = key.data(using: .utf8) else { return false }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: provider.rawValue
        ]
        let attrs: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        let updateStatus = SecItemUpdate(query as CFDictionary, attrs as CFDictionary)
        if updateStatus == errSecSuccess { return true }

        var add = query
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        let addStatus = SecItemAdd(add as CFDictionary, nil)
        return addStatus == errSecSuccess
    }

    static func load(for provider: Provider) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: provider.rawValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let key = String(data: data, encoding: .utf8) else { return nil }
        return key
    }

    @discardableResult
    static func delete(for provider: Provider) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: provider.rawValue
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    /// Removes every key the app knows about. Used when the user
    /// "Clear all keys".
    static func purge() {
        for provider in Provider.allCases { delete(for: provider) }
    }
}
