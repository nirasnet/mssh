import Foundation
import SwiftData

@Model
final class SSHKey {
    var label: String
    var keyType: String
    var keychainID: String
    var publicKeyText: String
    var createdAt: Date

    init(label: String, keyType: String, keychainID: String, publicKeyText: String) {
        self.label = label
        self.keyType = keyType
        self.keychainID = keychainID
        self.publicKeyText = publicKeyText
        self.createdAt = Date()
    }
}
