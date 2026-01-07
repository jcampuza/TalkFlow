import Foundation
@testable import TalkFlow

final class MockKeychainService: KeychainServiceProtocol {
    var storedAPIKey: String?

    func setAPIKey(_ key: String) {
        storedAPIKey = key
    }

    func getAPIKey() -> String? {
        return storedAPIKey
    }

    func deleteAPIKey() {
        storedAPIKey = nil
    }

    func hasAPIKey() -> Bool {
        return storedAPIKey != nil
    }

    func hasAPIKeyWithoutFetch() -> Bool {
        return storedAPIKey != nil
    }

    func migrateIfNeeded() {
        // No-op for mock
    }
}
