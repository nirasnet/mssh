import Foundation
import Crypto
import SwiftData
import Citadel

final class KeyManagementService {

    // MARK: - Ed25519 generation

    static func generateEd25519Key(label: String, modelContext: ModelContext, syncAcrossDevices: Bool = false) throws -> SSHKey {
        let privateKey = Curve25519.Signing.PrivateKey()
        let publicKey = privateKey.publicKey
        let keychainID = UUID().uuidString

        if syncAcrossDevices {
            try KeychainService.savePrivateKeySyncable(id: keychainID, pemData: privateKey.rawRepresentation)
        } else {
            try KeychainService.savePrivateKey(id: keychainID, pemData: privateKey.rawRepresentation)
        }

        let publicKeyText = formatOpenSSHPublicKey(
            publicKey: publicKey.rawRepresentation, type: "ed25519", label: label
        )

        let sshKey = SSHKey(
            label: label,
            keyType: "ed25519",
            keychainID: keychainID,
            publicKeyText: publicKeyText,
            syncAcrossDevices: syncAcrossDevices
        )
        modelContext.insert(sshKey)
        try modelContext.save()
        return sshKey
    }

    // MARK: - RSA generation
    // Note: RSA key generation requires BoringSSL internals not accessible from the app target.
    // Users should generate RSA keys on their Mac using ssh-keygen and import them.
    // Ed25519 is recommended for new key generation (faster, more secure, smaller keys).

    // MARK: - Import

    static func importKey(label: String, pemText: String, modelContext: ModelContext, syncAcrossDevices: Bool = false) throws -> SSHKey {
        guard let pemData = pemText.data(using: .utf8) else {
            throw KeyError.invalidPEM
        }

        let keyType = PEMParser.detectKeyType(pem: pemText)
        let keychainID = UUID().uuidString

        if syncAcrossDevices {
            try KeychainService.savePrivateKeySyncable(id: keychainID, pemData: pemData)
        } else {
            try KeychainService.savePrivateKey(id: keychainID, pemData: pemData)
        }

        let publicKeyText = derivePublicKeyText(pem: pemText, keyType: keyType, label: label)

        let sshKey = SSHKey(
            label: label,
            keyType: keyType,
            keychainID: keychainID,
            publicKeyText: publicKeyText,
            syncAcrossDevices: syncAcrossDevices
        )
        modelContext.insert(sshKey)
        try modelContext.save()
        return sshKey
    }

    // MARK: - Delete

    static func deleteKey(_ key: SSHKey, modelContext: ModelContext) {
        // Remove BOTH the local and iCloud-synced copies so a previously
        // synced private key doesn't linger in the user's iCloud Keychain
        // after they delete the key here.
        KeychainService.deletePrivateKey(id: key.keychainID)
        modelContext.delete(key)
    }

    // MARK: - Toggle sync disposition of an existing key

    /// Flip the sync flag on an existing SSHKey. Moves the private key bytes
    /// between device-local and iCloud-synced Keychain variants so the other
    /// devices can actually pick it up once the SwiftData row propagates.
    static func setSync(_ key: SSHKey, enabled: Bool, modelContext: ModelContext) {
        guard key.syncAcrossDevices != enabled else { return }
        _ = KeychainService.repinPrivateKeySync(id: key.keychainID, synced: enabled)
        key.syncAcrossDevices = enabled
        try? modelContext.save()
    }

    // MARK: - Public key derivation

    private static func derivePublicKeyText(pem: String, keyType: String, label: String) -> String {
        switch keyType {
        case "ed25519":
            if pem.contains("BEGIN OPENSSH PRIVATE KEY"),
               let rawKey = try? PEMParser.parseOpenSSHEd25519(pemString: pem),
               let pk = try? Curve25519.Signing.PrivateKey(rawRepresentation: rawKey) {
                return formatOpenSSHPublicKey(publicKey: pk.publicKey.rawRepresentation, type: "ed25519", label: label)
            }
        case "ecdsa-256":
            if let pk = try? P256.Signing.PrivateKey(pemRepresentation: pem) {
                return formatECDSAPublicKey(publicKeyData: pk.publicKey.rawRepresentation, curveName: "nistp256", label: label)
            }
        case "ecdsa-384":
            if let pk = try? P384.Signing.PrivateKey(pemRepresentation: pem) {
                return formatECDSAPublicKey(publicKeyData: pk.publicKey.rawRepresentation, curveName: "nistp384", label: label)
            }
        case "ecdsa-521":
            if let pk = try? P521.Signing.PrivateKey(pemRepresentation: pem) {
                return formatECDSAPublicKey(publicKeyData: pk.publicKey.rawRepresentation, curveName: "nistp521", label: label)
            }
        default:
            break
        }
        return "(imported \(keyType) key)"
    }

    // MARK: - OpenSSH public key formatting

    private static func formatOpenSSHPublicKey(publicKey: Data, type: String, label: String) -> String {
        var keyData = Data()
        let typeString = "ssh-\(type)"
        let typeBytes = typeString.data(using: .utf8)!
        appendSSHString(&keyData, typeBytes)
        appendSSHString(&keyData, publicKey)
        return "ssh-\(type) \(keyData.base64EncodedString()) \(label)"
    }

    private static func formatECDSAPublicKey(publicKeyData: Data, curveName: String, label: String) -> String {
        let typeString = "ecdsa-sha2-\(curveName)"
        var keyData = Data()
        appendSSHString(&keyData, typeString.data(using: .utf8)!)
        appendSSHString(&keyData, curveName.data(using: .utf8)!)
        appendSSHString(&keyData, publicKeyData)
        return "\(typeString) \(keyData.base64EncodedString()) \(label)"
    }

    private static func appendSSHString(_ data: inout Data, _ bytes: Data) {
        var len = UInt32(bytes.count).bigEndian
        data.append(Data(bytes: &len, count: 4))
        data.append(bytes)
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
