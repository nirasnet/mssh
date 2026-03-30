import Foundation
import CryptoKit
import SwiftData

/// Detected format of an SSH private key.
enum SSHKeyFormat: String {
    case openSSH = "OpenSSH"
    case pemPKCS1RSA = "PEM PKCS#1 (RSA)"
    case pemPKCS8 = "PEM PKCS#8"
    case puttyPPK = "PuTTY PPK"
    case unknown = "Unknown"
}

/// Detected type of an SSH key.
enum SSHKeyType: String {
    case rsa = "rsa"
    case ed25519 = "ed25519"
    case ecdsa256 = "ecdsa-sha2-nistp256"
    case ecdsa384 = "ecdsa-sha2-nistp384"
    case ecdsa521 = "ecdsa-sha2-nistp521"
    case unknown = "unknown"

    var shortName: String {
        switch self {
        case .rsa: return "RSA"
        case .ed25519: return "Ed25519"
        case .ecdsa256: return "ECDSA-256"
        case .ecdsa384: return "ECDSA-384"
        case .ecdsa521: return "ECDSA-521"
        case .unknown: return "Unknown"
        }
    }
}

/// Preview info for a key before import.
struct SSHKeyPreview: Identifiable {
    let id = UUID()
    let fileName: String
    let format: SSHKeyFormat
    let keyType: SSHKeyType
    let fingerprint: String
    let comment: String
    let publicKeyText: String?
    let rawPEM: String
    let isEncrypted: Bool

    var displayType: String {
        "\(keyType.shortName) (\(format.rawValue))"
    }
}

/// Errors specific to the import process.
enum SSHKeyImportError: LocalizedError {
    case notAPrivateKey
    case unsupportedFormat
    case encryptedKeyNeedsPassphrase
    case invalidKeyData
    case fileReadFailed(String)

    var errorDescription: String? {
        switch self {
        case .notAPrivateKey:
            return "The file does not appear to contain a private key."
        case .unsupportedFormat:
            return "This key format is not supported."
        case .encryptedKeyNeedsPassphrase:
            return "This key is encrypted with a passphrase. Encrypted key import is not yet supported."
        case .invalidKeyData:
            return "The key data could not be parsed."
        case .fileReadFailed(let path):
            return "Could not read file: \(path)"
        }
    }
}

/// Enhanced SSH key importer that handles detection, preview, and batch import.
final class SSHKeyImporter {

    // MARK: - Format Detection

    /// Detect the format of a key from its PEM text.
    static func detectFormat(_ text: String) -> SSHKeyFormat {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.hasPrefix("-----BEGIN OPENSSH PRIVATE KEY-----") {
            return .openSSH
        }
        if trimmed.hasPrefix("-----BEGIN RSA PRIVATE KEY-----") {
            return .pemPKCS1RSA
        }
        if trimmed.hasPrefix("-----BEGIN PRIVATE KEY-----") ||
           trimmed.hasPrefix("-----BEGIN ENCRYPTED PRIVATE KEY-----") {
            return .pemPKCS8
        }
        if trimmed.hasPrefix("-----BEGIN EC PRIVATE KEY-----") {
            return .pemPKCS1RSA // EC in PKCS#1 style
        }
        if trimmed.contains("PuTTY-User-Key-File") {
            return .puttyPPK
        }
        return .unknown
    }

    /// Detect the key type from PEM text.
    static func detectKeyType(_ text: String) -> SSHKeyType {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.hasPrefix("-----BEGIN RSA PRIVATE KEY-----") {
            return .rsa
        }
        if trimmed.hasPrefix("-----BEGIN EC PRIVATE KEY-----") {
            return detectECKeyType(trimmed)
        }
        if trimmed.hasPrefix("-----BEGIN OPENSSH PRIVATE KEY-----") {
            return detectOpenSSHKeyType(trimmed)
        }
        if trimmed.hasPrefix("-----BEGIN PRIVATE KEY-----") {
            return detectPKCS8KeyType(trimmed)
        }
        return .unknown
    }

    /// Check whether the key is passphrase-encrypted.
    static func isEncrypted(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // OpenSSH format: check the "encryption" field in the base64 blob
        if trimmed.hasPrefix("-----BEGIN OPENSSH PRIVATE KEY-----") {
            // In OpenSSH format, encrypted keys have a cipher name != "none"
            // We look for the decoded header bytes
            if let decoded = decodeOpenSSHBody(trimmed) {
                // The auth magic is "openssh-key-v1\0", then ciphername length + ciphername
                let magic = "openssh-key-v1\0"
                guard decoded.count > magic.utf8.count + 8 else { return false }
                let offset = magic.utf8.count
                let cipherNameLen = decoded.subdata(in: offset..<(offset + 4)).withUnsafeBytes {
                    UInt32(bigEndian: $0.load(as: UInt32.self))
                }
                let cipherStart = offset + 4
                let cipherEnd = cipherStart + Int(cipherNameLen)
                guard cipherEnd <= decoded.count else { return false }
                let cipherName = String(data: decoded.subdata(in: cipherStart..<cipherEnd), encoding: .utf8) ?? ""
                return cipherName != "none"
            }
        }

        // PEM PKCS#1: look for "Proc-Type: 4,ENCRYPTED" or "DEK-Info:"
        if trimmed.contains("Proc-Type: 4,ENCRYPTED") || trimmed.contains("DEK-Info:") {
            return true
        }

        // PKCS#8 encrypted
        if trimmed.hasPrefix("-----BEGIN ENCRYPTED PRIVATE KEY-----") {
            return true
        }

        return false
    }

    // MARK: - Fingerprint

    /// Compute a SHA-256 fingerprint from a public key blob (base64 from authorized_keys format).
    static func computeFingerprint(publicKeyBase64: String) -> String {
        guard let data = Data(base64Encoded: publicKeyBase64) else {
            return "unknown"
        }
        let hash = SHA256.hash(data: data)
        let encoded = Data(hash).base64EncodedString()
            .replacingOccurrences(of: "=", with: "")
        return "SHA256:\(encoded)"
    }

    /// Extract a fingerprint from the raw PEM text. This is a best-effort approach.
    static func fingerprintFromPEM(_ text: String) -> String {
        // For OpenSSH keys, we can extract the public key from the private key blob
        // For other formats, we hash the whole key as a placeholder
        let data = text.data(using: .utf8) ?? Data()
        let hash = SHA256.hash(data: data)
        let encoded = Data(hash).base64EncodedString()
            .replacingOccurrences(of: "=", with: "")
        return "SHA256:\(encoded.prefix(43))"
    }

    // MARK: - Preview

    /// Generate a preview for a single key file.
    static func preview(text: String, fileName: String) -> SSHKeyPreview {
        let format = detectFormat(text)
        let keyType = detectKeyType(text)
        let encrypted = isEncrypted(text)
        let fingerprint = fingerprintFromPEM(text)
        let comment = extractComment(text)

        return SSHKeyPreview(
            fileName: fileName,
            format: format,
            keyType: keyType,
            fingerprint: fingerprint,
            comment: comment,
            publicKeyText: nil,
            rawPEM: text,
            isEncrypted: encrypted
        )
    }

    /// Scan a directory URL for SSH key files and return previews.
    static func scanDirectory(url: URL) -> [SSHKeyPreview] {
        var previews: [SSHKeyPreview] = []
        let fm = FileManager.default

        guard let enumerator = fm.enumerator(at: url, includingPropertiesForKeys: [.isRegularFileKey],
                                              options: [.skipsHiddenFiles, .skipsPackageDescendants]) else {
            return []
        }

        for case let fileURL as URL in enumerator {
            guard let values = try? fileURL.resourceValues(forKeys: [.isRegularFileKey]),
                  values.isRegularFile == true else { continue }

            // Skip files that are clearly not keys
            let name = fileURL.lastPathComponent
            if name.hasSuffix(".pub") { continue }
            if name.hasSuffix(".DS_Store") { continue }

            guard let data = try? Data(contentsOf: fileURL),
                  let text = String(data: data, encoding: .utf8) else { continue }

            let format = detectFormat(text)
            if format != .unknown {
                previews.append(preview(text: text, fileName: name))
            }
        }

        return previews
    }

    // MARK: - Import

    /// Import a single key into SwiftData + Keychain.
    @discardableResult
    static func importKey(
        preview: SSHKeyPreview,
        label: String,
        modelContext: ModelContext
    ) throws -> SSHKey {
        guard preview.format != .unknown else {
            throw SSHKeyImportError.unsupportedFormat
        }
        if preview.isEncrypted {
            throw SSHKeyImportError.encryptedKeyNeedsPassphrase
        }

        guard let pemData = preview.rawPEM.data(using: .utf8) else {
            throw SSHKeyImportError.invalidKeyData
        }

        let keychainID = UUID().uuidString
        try KeychainService.savePrivateKey(id: keychainID, pemData: pemData)

        let sshKey = SSHKey(
            label: label,
            keyType: preview.keyType.rawValue,
            keychainID: keychainID,
            publicKeyText: preview.publicKeyText ?? "(imported \(preview.keyType.shortName) key)"
        )
        modelContext.insert(sshKey)
        return sshKey
    }

    /// Batch import multiple keys.
    static func batchImport(
        previews: [SSHKeyPreview],
        modelContext: ModelContext
    ) -> (imported: [SSHKey], errors: [(String, Error)]) {
        var imported: [SSHKey] = []
        var errors: [(String, Error)] = []

        for preview in previews {
            do {
                let key = try importKey(
                    preview: preview,
                    label: preview.fileName,
                    modelContext: modelContext
                )
                imported.append(key)
            } catch {
                errors.append((preview.fileName, error))
            }
        }

        return (imported, errors)
    }

    // MARK: - Private Helpers

    private static func detectOpenSSHKeyType(_ text: String) -> SSHKeyType {
        guard let decoded = decodeOpenSSHBody(text) else { return .unknown }

        // After "openssh-key-v1\0", skip cipher name, kdf name, kdf options, num keys,
        // then read the public key type string.
        let magic = "openssh-key-v1\0"
        var offset = magic.utf8.count

        // Skip: ciphername, kdfname, kdfoptions (each length-prefixed)
        for _ in 0..<3 {
            guard offset + 4 <= decoded.count else { return .unknown }
            let len = decoded.subdata(in: offset..<(offset + 4)).withUnsafeBytes {
                Int(UInt32(bigEndian: $0.load(as: UInt32.self)))
            }
            offset += 4 + len
        }

        // Number of keys
        guard offset + 4 <= decoded.count else { return .unknown }
        offset += 4

        // Public key blob (length-prefixed)
        guard offset + 4 <= decoded.count else { return .unknown }
        let pubLen = decoded.subdata(in: offset..<(offset + 4)).withUnsafeBytes {
            Int(UInt32(bigEndian: $0.load(as: UInt32.self)))
        }
        offset += 4

        guard offset + 4 <= decoded.count else { return .unknown }
        let typeLen = decoded.subdata(in: offset..<(offset + 4)).withUnsafeBytes {
            Int(UInt32(bigEndian: $0.load(as: UInt32.self)))
        }
        offset += 4

        guard offset + typeLen <= decoded.count else { return .unknown }
        let typeStr = String(data: decoded.subdata(in: offset..<(offset + typeLen)), encoding: .utf8) ?? ""

        return keyTypeFromString(typeStr)
    }

    private static func detectECKeyType(_ text: String) -> SSHKeyType {
        // EC keys in PEM might have an OID or we can check the key size
        if text.contains("nistp256") || text.contains("prime256v1") { return .ecdsa256 }
        if text.contains("nistp384") || text.contains("secp384r1") { return .ecdsa384 }
        if text.contains("nistp521") || text.contains("secp521r1") { return .ecdsa521 }
        // Default to 256 for generic EC keys
        return .ecdsa256
    }

    private static func detectPKCS8KeyType(_ text: String) -> SSHKeyType {
        // PKCS#8 uses OIDs; we'd need ASN.1 parsing for full accuracy.
        // Heuristic: decode base64 and look for known OID bytes.
        guard let decoded = decodePEMBody(text) else { return .unknown }

        // RSA OID: 1.2.840.113549.1.1.1 -> 2a 86 48 86 f7 0d 01 01 01
        let rsaOID = Data([0x2a, 0x86, 0x48, 0x86, 0xf7, 0x0d, 0x01, 0x01, 0x01])
        if decoded.range(of: rsaOID) != nil { return .rsa }

        // Ed25519 OID: 1.3.101.112 -> 2b 65 70
        let ed25519OID = Data([0x2b, 0x65, 0x70])
        if decoded.range(of: ed25519OID) != nil { return .ed25519 }

        // ECDSA OID for P-256: 1.2.840.10045.3.1.7 -> 2a 86 48 ce 3d 03 01 07
        let p256OID = Data([0x2a, 0x86, 0x48, 0xce, 0x3d, 0x03, 0x01, 0x07])
        if decoded.range(of: p256OID) != nil { return .ecdsa256 }

        // P-384: 1.3.132.0.34 -> 2b 81 04 00 22
        let p384OID = Data([0x2b, 0x81, 0x04, 0x00, 0x22])
        if decoded.range(of: p384OID) != nil { return .ecdsa384 }

        // P-521: 1.3.132.0.35 -> 2b 81 04 00 23
        let p521OID = Data([0x2b, 0x81, 0x04, 0x00, 0x23])
        if decoded.range(of: p521OID) != nil { return .ecdsa521 }

        return .unknown
    }

    private static func keyTypeFromString(_ s: String) -> SSHKeyType {
        switch s {
        case "ssh-rsa": return .rsa
        case "ssh-ed25519": return .ed25519
        case "ecdsa-sha2-nistp256": return .ecdsa256
        case "ecdsa-sha2-nistp384": return .ecdsa384
        case "ecdsa-sha2-nistp521": return .ecdsa521
        default: return .unknown
        }
    }

    private static func decodeOpenSSHBody(_ text: String) -> Data? {
        let lines = text.components(separatedBy: .newlines)
            .filter { !$0.hasPrefix("-----") && !$0.isEmpty }
        let base64 = lines.joined()
        return Data(base64Encoded: base64)
    }

    private static func decodePEMBody(_ text: String) -> Data? {
        let lines = text.components(separatedBy: .newlines)
            .filter { !$0.hasPrefix("-----") && !$0.hasPrefix("Proc-Type") && !$0.hasPrefix("DEK-Info") && !$0.isEmpty }
        let base64 = lines.joined()
        return Data(base64Encoded: base64)
    }

    private static func extractComment(_ text: String) -> String {
        // OpenSSH keys sometimes have a comment at the end of the key blob.
        // For now return the first line after headers as a heuristic.
        let lines = text.components(separatedBy: .newlines)
        for line in lines where line.hasPrefix("Comment:") {
            return String(line.dropFirst("Comment:".count)).trimmingCharacters(in: .whitespaces)
        }
        return ""
    }
}
