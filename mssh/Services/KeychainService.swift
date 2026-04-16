import Foundation
import Security

enum KeychainService {
    private static let serviceName = "com.m4ck.mssh"

    // MARK: - Device-Only Password (original behavior)

    static func savePassword(for profileID: String, password: String) throws {
        guard let data = password.data(using: .utf8) else { return }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: "pwd-\(profileID)",
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }

    static func getPassword(for profileID: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: "pwd-\(profileID)",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    // MARK: - Syncable Password (iCloud Keychain)

    /// Saves a password that syncs across devices via iCloud Keychain.
    /// Use the profile's `syncID` as the identifier so the password matches on every device.
    static func savePasswordSyncable(for syncID: String, password: String) throws {
        guard let data = password.data(using: .utf8) else { return }

        // Delete any existing item first (must also specify synchronizable for deletion)
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: "pwd-sync-\(syncID)",
            kSecAttrSynchronizable as String: kSecAttrSynchronizableAny
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: "pwd-sync-\(syncID)",
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked,
            kSecAttrSynchronizable as String: true
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }

    /// Retrieves a syncable password from iCloud Keychain using the profile's `syncID`.
    static func getPasswordSyncable(for syncID: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: "pwd-sync-\(syncID)",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecAttrSynchronizable as String: true
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// Deletes a syncable password from iCloud Keychain.
    static func deletePasswordSyncable(for syncID: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: "pwd-sync-\(syncID)",
            kSecAttrSynchronizable as String: kSecAttrSynchronizableAny
        ]
        SecItemDelete(query as CFDictionary)
    }

    // MARK: - Private Keys (device-only, never synced)

    static func savePrivateKey(id: String, pemData: Data) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: "key-\(id)",
            kSecValueData as String: pemData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }

    static func getPrivateKey(id: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: "key-\(id)",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
            // Match both device-local AND iCloud-synced items so the
            // resolver finds a key regardless of which way the SSHKey's
            // syncAcrossDevices flag was set at save time.
            kSecAttrSynchronizable as String: kSecAttrSynchronizableAny
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return data
    }

    // MARK: - Syncable Private Keys (opt-in, iCloud Keychain)

    /// Saves a private key to iCloud Keychain so it becomes available on
    /// other devices signed into the same Apple ID. iCloud Keychain is
    /// end-to-end encrypted by Apple. Accessibility is `WhenUnlocked` (not
    /// `ThisDeviceOnly`) because the item must survive sync.
    static func savePrivateKeySyncable(id: String, pemData: Data) throws {
        // Wipe both variants (local + syncable) so we never have conflicting
        // bytes under the same account name after a flag toggle.
        deletePrivateKey(id: id)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: "key-\(id)",
            kSecValueData as String: pemData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked,
            kSecAttrSynchronizable as String: true
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }

    /// Re-save an existing key under the alternate sync disposition. Used
    /// when the user toggles `SSHKey.syncAcrossDevices` on an already-imported
    /// key. No-op (returns nil) if the key isn't in the Keychain here yet.
    @discardableResult
    static func repinPrivateKeySync(id: String, synced: Bool) -> Bool {
        guard let existing = getPrivateKey(id: id) else { return false }
        deletePrivateKey(id: id)
        do {
            if synced {
                try savePrivateKeySyncable(id: id, pemData: existing)
            } else {
                try savePrivateKey(id: id, pemData: existing)
            }
            return true
        } catch {
            return false
        }
    }

    /// Remove a private key regardless of its sync disposition.
    static func deletePrivateKey(id: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: "key-\(id)",
            kSecAttrSynchronizable as String: kSecAttrSynchronizableAny
        ]
        SecItemDelete(query as CFDictionary)
    }

    // MARK: - Host Keys (device-only)

    static func saveHostKey(host: String, port: Int, keyData: Data) throws {
        let account = "hostkey-\(host):\(port)"
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account,
            kSecValueData as String: keyData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }

    static func getHostKey(host: String, port: Int) -> Data? {
        let account = "hostkey-\(host):\(port)"
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return data
    }

    // MARK: - Deletion

    static func deleteItem(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}

enum KeychainError: LocalizedError {
    case saveFailed(OSStatus)

    var errorDescription: String? {
        switch self {
        case .saveFailed(let status):
            return "Keychain save failed with status: \(status)"
        }
    }
}
