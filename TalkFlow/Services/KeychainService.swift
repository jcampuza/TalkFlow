import Foundation
import Security

protocol KeychainServiceProtocol {
    func setAPIKey(_ key: String)
    func getAPIKey() -> String?
    func deleteAPIKey()
    func hasAPIKey() -> Bool
    func migrateIfNeeded()
}

final class KeychainService: KeychainServiceProtocol {
    private let service = "com.josephcampuzano.TalkFlow"
    private let apiKeyAccount = "openai-api-key"
    private let migrationKey = "keychain-migration-v1"

    func setAPIKey(_ key: String) {
        // Delete existing key first
        deleteAPIKey()

        guard let data = key.data(using: .utf8) else {
            Logger.shared.error("Failed to encode API key data", component: "Keychain")
            return
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: apiKeyAccount,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        let status = SecItemAdd(query as CFDictionary, nil)

        if status == errSecSuccess {
            Logger.shared.info("API key saved to Keychain", component: "Keychain")
        } else {
            Logger.shared.error("Failed to save API key: \(status)", component: "Keychain")
        }
    }

    func migrateIfNeeded() {
        // No-op for now - migration not needed with simple approach
    }

    func getAPIKey() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: apiKeyAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let key = String(data: data, encoding: .utf8) else {
            return nil
        }

        return key
    }

    func deleteAPIKey() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: apiKeyAccount
        ]

        let status = SecItemDelete(query as CFDictionary)

        if status == errSecSuccess || status == errSecItemNotFound {
            Logger.shared.debug("API key deleted from Keychain", component: "Keychain")
        }
    }

    func hasAPIKey() -> Bool {
        return getAPIKey() != nil
    }
}
