import Foundation
import CryptoKit
import SwiftData

final class KeyManagementService {

    /// Generate an Ed25519 key pair, store private key in Keychain, return metadata
    static func generateEd25519Key(label: String, modelContext: ModelContext) throws -> SSHKey {
        let privateKey = Curve25519.Signing.PrivateKey()
        let publicKey = privateKey.publicKey

        let keychainID = UUID().uuidString
        let privateKeyRaw = privateKey.rawRepresentation

        // Store private key in keychain
        try KeychainService.savePrivateKey(id: keychainID, pemData: privateKeyRaw)

        // Format public key in OpenSSH format
        let publicKeyText = formatOpenSSHPublicKey(publicKey: publicKey.rawRepresentation, type: "ed25519", label: label)

        let sshKey = SSHKey(
            label: label,
            keyType: "ed25519",
            keychainID: keychainID,
            publicKeyText: publicKeyText
        )
        modelContext.insert(sshKey)
        return sshKey
    }

    /// Import a PEM private key from raw text
    static func importKey(label: String, pemText: String, modelContext: ModelContext) throws -> SSHKey {
        guard let pemData = pemText.data(using: .utf8) else {
            throw KeyError.invalidPEM
        }

        let keyType = detectKeyType(pem: pemText)
        let keychainID = UUID().uuidString

        try KeychainService.savePrivateKey(id: keychainID, pemData: pemData)

        let sshKey = SSHKey(
            label: label,
            keyType: keyType,
            keychainID: keychainID,
            publicKeyText: "(imported \(keyType) key)"
        )
        modelContext.insert(sshKey)
        return sshKey
    }

    static func deleteKey(_ key: SSHKey, modelContext: ModelContext) {
        KeychainService.deleteItem(account: "key-\(key.keychainID)")
        modelContext.delete(key)
    }

    private static func detectKeyType(pem: String) -> String {
        if pem.contains("RSA") { return "rsa" }
        if pem.contains("EC") { return "ecdsa" }
        if pem.contains("OPENSSH") { return "ed25519" }
        return "unknown"
    }

    private static func formatOpenSSHPublicKey(publicKey: Data, type: String, label: String) -> String {
        // Simplified OpenSSH public key encoding for ed25519
        var keyData = Data()
        let typeString = "ssh-\(type)"
        let typeBytes = typeString.data(using: .utf8)!

        // Length-prefixed type string
        var typeLen = UInt32(typeBytes.count).bigEndian
        keyData.append(Data(bytes: &typeLen, count: 4))
        keyData.append(typeBytes)

        // Length-prefixed public key
        var keyLen = UInt32(publicKey.count).bigEndian
        keyData.append(Data(bytes: &keyLen, count: 4))
        keyData.append(publicKey)

        let base64 = keyData.base64EncodedString()
        return "ssh-\(type) \(base64) \(label)"
    }
}

enum KeyError: LocalizedError {
    case invalidPEM
    case generationFailed

    var errorDescription: String? {
        switch self {
        case .invalidPEM: return "Invalid PEM key data"
        case .generationFailed: return "Key generation failed"
        }
    }
}
