import Foundation
import SwiftData

@Model
final class SSHKey {
    var label: String = ""
    var keyType: String = ""
    var publicKeyText: String = ""
    var createdAt: Date = Date()

    /// Stable identifier for cross-device sync.
    var syncID: String = UUID().uuidString

    /// Reference to the private key in the local Keychain. Device-specific -- private keys
    /// are NOT synced via CloudKit. Each device stores its own copy in the local Keychain.
    var keychainID: String = ""

    /// When true, the private key material is stored in the iCloud-synced
    /// Keychain (kSecAttrSynchronizable:true + kSecAttrAccessibleWhenUnlocked)
    /// so it's available on other devices signed into the same Apple ID. iCloud
    /// Keychain is end-to-end encrypted by Apple; disabling stores only on
    /// this device (WhenUnlockedThisDeviceOnly). Defaults to false — explicit
    /// opt-in via the Keys tab.
    var syncAcrossDevices: Bool = false

    init(label: String, keyType: String, keychainID: String, publicKeyText: String, syncAcrossDevices: Bool = false) {
        self.label = label
        self.keyType = keyType
        self.keychainID = keychainID
        self.publicKeyText = publicKeyText
        self.createdAt = Date()
        self.syncID = UUID().uuidString
        self.syncAcrossDevices = syncAcrossDevices
    }
}
