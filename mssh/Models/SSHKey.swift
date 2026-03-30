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

    init(label: String, keyType: String, keychainID: String, publicKeyText: String) {
        self.label = label
        self.keyType = keyType
        self.keychainID = keychainID
        self.publicKeyText = publicKeyText
        self.createdAt = Date()
        self.syncID = UUID().uuidString
    }
}
