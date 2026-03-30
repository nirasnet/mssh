import Foundation
import Citadel
import Crypto

// MARK: - PEM Parser

/// Parses PEM-encoded private keys and detects key types.
/// RSA keys in PKCS#1/PKCS#8/OpenSSH formats are parsed into raw components
/// that can be used with Citadel's `Insecure.RSA.PrivateKey`.
enum PEMParser {

    enum PEMError: LocalizedError {
        case invalidPEMStructure
        case unsupportedKeyType
        case invalidASN1
        case invalidOpenSSHKey
        case encryptedKeyNotSupported
        case rsaComponentExtractionFailed

        var errorDescription: String? {
            switch self {
            case .invalidPEMStructure:      return "Invalid PEM structure"
            case .unsupportedKeyType:       return "Unsupported key type"
            case .invalidASN1:              return "Invalid ASN.1 / DER encoding"
            case .invalidOpenSSHKey:        return "Invalid OpenSSH private key"
            case .encryptedKeyNotSupported: return "Encrypted keys are not yet supported"
            case .rsaComponentExtractionFailed: return "Failed to extract RSA components"
            }
        }
    }

    /// Raw RSA key components extracted from PEM
    struct RSAKeyComponents {
        let modulus: Data          // n
        let publicExponent: Data   // e
        let privateExponent: Data  // d
    }

    // MARK: - Public API

    /// Parse an RSA private key from PEM, returning raw components.
    static func parseRSAComponents(pemString: String) throws -> RSAKeyComponents? {
        let trimmed = pemString.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.contains("BEGIN RSA PRIVATE KEY") {
            return try parsePKCS1Components(pem: trimmed)
        } else if trimmed.contains("BEGIN PRIVATE KEY") {
            return try parsePKCS8Components(pem: trimmed)
        } else if trimmed.contains("BEGIN OPENSSH PRIVATE KEY") {
            return try parseOpenSSHRSAComponents(pem: trimmed)
        }
        return nil
    }

    /// Parse an OpenSSH ed25519 private key, returning the 32-byte raw private key.
    static func parseOpenSSHEd25519(pemString: String) throws -> Data? {
        let der = try extractDERPayload(
            pem: pemString,
            header: "-----BEGIN OPENSSH PRIVATE KEY-----",
            footer: "-----END OPENSSH PRIVATE KEY-----"
        )

        let buf = Array(der)
        let magic = "openssh-key-v1"
        guard buf.count > magic.utf8.count + 1,
              Array(buf[0..<magic.utf8.count]) == Array(magic.utf8),
              buf[magic.utf8.count] == 0x00 else {
            throw PEMError.invalidOpenSSHKey
        }

        var offset = magic.utf8.count + 1

        // Skip cipher, kdf, kdf options
        guard let cipherLen = readUInt32(buf, at: &offset) else { throw PEMError.invalidOpenSSHKey }
        let cipherName = String(bytes: buf[offset..<(offset + Int(cipherLen))], encoding: .utf8) ?? ""
        offset += Int(cipherLen)
        if cipherName != "none" { throw PEMError.encryptedKeyNotSupported }

        guard let kdfLen = readUInt32(buf, at: &offset) else { throw PEMError.invalidOpenSSHKey }
        offset += Int(kdfLen)
        guard let kdfOptLen = readUInt32(buf, at: &offset) else { throw PEMError.invalidOpenSSHKey }
        offset += Int(kdfOptLen)

        guard let numKeys = readUInt32(buf, at: &offset), numKeys == 1 else { throw PEMError.invalidOpenSSHKey }

        // Skip public key blob
        guard let pubBlobLen = readUInt32(buf, at: &offset) else { throw PEMError.invalidOpenSSHKey }
        offset += Int(pubBlobLen)

        // Private key section
        guard let _ = readUInt32(buf, at: &offset) else { throw PEMError.invalidOpenSSHKey }

        guard let check0 = readUInt32(buf, at: &offset),
              let check1 = readUInt32(buf, at: &offset),
              check0 == check1 else { throw PEMError.invalidOpenSSHKey }

        guard let keyTypeLen = readUInt32(buf, at: &offset) else { throw PEMError.invalidOpenSSHKey }
        let keyType = String(bytes: buf[offset..<(offset + Int(keyTypeLen))], encoding: .utf8) ?? ""
        offset += Int(keyTypeLen)

        guard keyType == "ssh-ed25519" else { return nil }

        // Skip public key
        guard let pubKeyLen = readUInt32(buf, at: &offset) else { throw PEMError.invalidOpenSSHKey }
        offset += Int(pubKeyLen)

        // ed25519 private key: 64 bytes (32 private + 32 public)
        guard let privKeyLen = readUInt32(buf, at: &offset) else { throw PEMError.invalidOpenSSHKey }
        guard privKeyLen == 64, offset + 64 <= buf.count else { throw PEMError.invalidOpenSSHKey }

        return Data(buf[offset..<(offset + 32)])
    }

    // MARK: - PKCS#1 ASN.1 parsing

    private static func parsePKCS1Components(pem: String) throws -> RSAKeyComponents {
        let der = try extractDERPayload(pem: pem, header: "-----BEGIN RSA PRIVATE KEY-----", footer: "-----END RSA PRIVATE KEY-----")
        let bytes = Array(der)
        var offset = 0

        // SEQUENCE
        guard readASN1Tag(bytes, at: &offset) == 0x30 else { throw PEMError.invalidASN1 }
        _ = try readASN1Length(bytes, at: &offset)

        // version INTEGER
        _ = try readASN1Integer(bytes, at: &offset)
        // modulus (n)
        let n = try readASN1Integer(bytes, at: &offset)
        // publicExponent (e)
        let e = try readASN1Integer(bytes, at: &offset)
        // privateExponent (d)
        let d = try readASN1Integer(bytes, at: &offset)

        return RSAKeyComponents(modulus: Data(n), publicExponent: Data(e), privateExponent: Data(d))
    }

    // MARK: - PKCS#8 ASN.1 parsing

    private static func parsePKCS8Components(pem: String) throws -> RSAKeyComponents? {
        let der = try extractDERPayload(pem: pem, header: "-----BEGIN PRIVATE KEY-----", footer: "-----END PRIVATE KEY-----")
        let bytes = Array(der)
        var offset = 0

        // Outer SEQUENCE
        guard readASN1Tag(bytes, at: &offset) == 0x30 else { throw PEMError.invalidASN1 }
        _ = try readASN1Length(bytes, at: &offset)

        // version INTEGER
        _ = try readASN1Integer(bytes, at: &offset)

        // AlgorithmIdentifier SEQUENCE
        guard readASN1Tag(bytes, at: &offset) == 0x30 else { throw PEMError.invalidASN1 }
        let algoLen = try readASN1Length(bytes, at: &offset)
        let algoEnd = offset + algoLen

        // Check OID for RSA: 1.2.840.113549.1.1.1
        let rsaOID: [UInt8] = [0x06, 0x09, 0x2A, 0x86, 0x48, 0x86, 0xF7, 0x0D, 0x01, 0x01, 0x01]
        let algoBytes = Array(bytes[offset..<min(algoEnd, bytes.count)])
        guard algoBytes.starts(with: rsaOID) else {
            return nil // Not RSA
        }
        offset = algoEnd

        // privateKey OCTET STRING containing PKCS#1 DER
        guard readASN1Tag(bytes, at: &offset) == 0x04 else { throw PEMError.invalidASN1 }
        let octetLen = try readASN1Length(bytes, at: &offset)
        let pkcs1Bytes = Array(bytes[offset..<(offset + octetLen)])

        // Parse inner PKCS#1 structure
        var innerOffset = 0
        guard readASN1Tag(pkcs1Bytes, at: &innerOffset) == 0x30 else { throw PEMError.invalidASN1 }
        _ = try readASN1Length(pkcs1Bytes, at: &innerOffset)
        _ = try readASN1Integer(pkcs1Bytes, at: &innerOffset) // version
        let n = try readASN1Integer(pkcs1Bytes, at: &innerOffset)
        let e = try readASN1Integer(pkcs1Bytes, at: &innerOffset)
        let d = try readASN1Integer(pkcs1Bytes, at: &innerOffset)

        return RSAKeyComponents(modulus: Data(n), publicExponent: Data(e), privateExponent: Data(d))
    }

    // MARK: - OpenSSH RSA parsing

    private static func parseOpenSSHRSAComponents(pem: String) throws -> RSAKeyComponents? {
        let der = try extractDERPayload(
            pem: pem,
            header: "-----BEGIN OPENSSH PRIVATE KEY-----",
            footer: "-----END OPENSSH PRIVATE KEY-----"
        )

        let buf = Array(der)
        let magic = "openssh-key-v1"
        guard buf.count > magic.utf8.count + 1,
              Array(buf[0..<magic.utf8.count]) == Array(magic.utf8),
              buf[magic.utf8.count] == 0x00 else { throw PEMError.invalidOpenSSHKey }

        var offset = magic.utf8.count + 1

        guard let cipherLen = readUInt32(buf, at: &offset) else { throw PEMError.invalidOpenSSHKey }
        let cipherName = String(bytes: buf[offset..<(offset + Int(cipherLen))], encoding: .utf8) ?? ""
        offset += Int(cipherLen)
        if cipherName != "none" { throw PEMError.encryptedKeyNotSupported }

        guard let kdfLen = readUInt32(buf, at: &offset) else { throw PEMError.invalidOpenSSHKey }
        offset += Int(kdfLen)
        guard let kdfOptLen = readUInt32(buf, at: &offset) else { throw PEMError.invalidOpenSSHKey }
        offset += Int(kdfOptLen)

        guard let numKeys = readUInt32(buf, at: &offset), numKeys == 1 else { throw PEMError.invalidOpenSSHKey }

        guard let pubBlobLen = readUInt32(buf, at: &offset) else { throw PEMError.invalidOpenSSHKey }
        offset += Int(pubBlobLen)

        guard let _ = readUInt32(buf, at: &offset) else { throw PEMError.invalidOpenSSHKey }

        guard let check0 = readUInt32(buf, at: &offset),
              let check1 = readUInt32(buf, at: &offset),
              check0 == check1 else { throw PEMError.invalidOpenSSHKey }

        guard let keyTypeLen = readUInt32(buf, at: &offset) else { throw PEMError.invalidOpenSSHKey }
        let keyType = String(bytes: buf[offset..<(offset + Int(keyTypeLen))], encoding: .utf8) ?? ""
        offset += Int(keyTypeLen)

        guard keyType == "ssh-rsa" else { return nil }

        // OpenSSH RSA: mpint n, mpint e, mpint d, ...
        guard let nBytes = readSSHBytes(buf, at: &offset),
              let eBytes = readSSHBytes(buf, at: &offset),
              let dBytes = readSSHBytes(buf, at: &offset) else {
            throw PEMError.invalidOpenSSHKey
        }

        return RSAKeyComponents(
            modulus: Data(stripLeadingZeros(nBytes)),
            publicExponent: Data(stripLeadingZeros(eBytes)),
            privateExponent: Data(stripLeadingZeros(dBytes))
        )
    }

    // MARK: - Key type detection

    static func detectKeyType(pem: String) -> String {
        let trimmed = pem.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.contains("BEGIN RSA PRIVATE KEY") { return "rsa" }
        if trimmed.contains("BEGIN EC PRIVATE KEY") { return "ecdsa" }

        if trimmed.contains("BEGIN OPENSSH PRIVATE KEY") {
            return detectOpenSSHKeyType(pem: trimmed)
        }
        if trimmed.contains("BEGIN PRIVATE KEY") {
            return detectPKCS8KeyType(pem: trimmed)
        }
        return "unknown"
    }

    private static func detectOpenSSHKeyType(pem: String) -> String {
        do {
            let der = try extractDERPayload(pem: pem, header: "-----BEGIN OPENSSH PRIVATE KEY-----", footer: "-----END OPENSSH PRIVATE KEY-----")
            var buf = Array(der)
            let magic = "openssh-key-v1"
            guard buf.count > magic.utf8.count + 1 else { return "unknown" }

            var offset = magic.utf8.count + 1
            guard let cipherLen = readUInt32(buf, at: &offset) else { return "unknown" }
            offset += Int(cipherLen)
            guard let kdfLen = readUInt32(buf, at: &offset) else { return "unknown" }
            offset += Int(kdfLen)
            guard let kdfOptLen = readUInt32(buf, at: &offset) else { return "unknown" }
            offset += Int(kdfOptLen)
            guard let _ = readUInt32(buf, at: &offset) else { return "unknown" }
            guard let pubBlobLen = readUInt32(buf, at: &offset) else { return "unknown" }
            let pubBlobEnd = offset + Int(pubBlobLen)
            guard pubBlobEnd <= buf.count else { return "unknown" }

            guard let keyTypeLen = readUInt32(buf, at: &offset) else { return "unknown" }
            let keyType = String(bytes: buf[offset..<(offset + Int(keyTypeLen))], encoding: .utf8) ?? ""

            switch keyType {
            case "ssh-rsa":             return "rsa"
            case "ssh-ed25519":         return "ed25519"
            case "ecdsa-sha2-nistp256": return "ecdsa-256"
            case "ecdsa-sha2-nistp384": return "ecdsa-384"
            case "ecdsa-sha2-nistp521": return "ecdsa-521"
            default:                    return "unknown"
            }
        } catch { return "unknown" }
    }

    private static func detectPKCS8KeyType(pem: String) -> String {
        guard let der = try? extractDERPayload(pem: pem, header: "-----BEGIN PRIVATE KEY-----", footer: "-----END PRIVATE KEY-----") else { return "unknown" }
        let bytes = Array(der)

        let rsaOID: [UInt8] = [0x06, 0x09, 0x2A, 0x86, 0x48, 0x86, 0xF7, 0x0D, 0x01, 0x01, 0x01]
        let ecOID:  [UInt8] = [0x06, 0x07, 0x2A, 0x86, 0x48, 0xCE, 0x3D, 0x02, 0x01]
        let ed25519OID: [UInt8] = [0x06, 0x03, 0x2B, 0x65, 0x70]

        if containsSubsequence(bytes, rsaOID) { return "rsa" }
        if containsSubsequence(bytes, ed25519OID) { return "ed25519" }
        if containsSubsequence(bytes, ecOID) {
            let p256: [UInt8] = [0x06, 0x08, 0x2A, 0x86, 0x48, 0xCE, 0x3D, 0x03, 0x01, 0x07]
            let p384: [UInt8] = [0x06, 0x05, 0x2B, 0x81, 0x04, 0x00, 0x22]
            let p521: [UInt8] = [0x06, 0x05, 0x2B, 0x81, 0x04, 0x00, 0x23]
            if containsSubsequence(bytes, p256) { return "ecdsa-256" }
            if containsSubsequence(bytes, p384) { return "ecdsa-384" }
            if containsSubsequence(bytes, p521) { return "ecdsa-521" }
            return "ecdsa"
        }
        return "unknown"
    }

    // MARK: - ASN.1 DER helpers

    private static func readASN1Tag(_ bytes: [UInt8], at offset: inout Int) -> UInt8? {
        guard offset < bytes.count else { return nil }
        let tag = bytes[offset]
        offset += 1
        return tag
    }

    private static func readASN1Length(_ bytes: [UInt8], at offset: inout Int) throws -> Int {
        guard offset < bytes.count else { throw PEMError.invalidASN1 }
        let first = bytes[offset]
        offset += 1

        if first < 0x80 {
            return Int(first)
        }

        let numBytes = Int(first & 0x7F)
        guard numBytes <= 4, offset + numBytes <= bytes.count else { throw PEMError.invalidASN1 }

        var length = 0
        for i in 0..<numBytes {
            length = (length << 8) | Int(bytes[offset + i])
        }
        offset += numBytes
        return length
    }

    private static func readASN1Integer(_ bytes: [UInt8], at offset: inout Int) throws -> [UInt8] {
        guard readASN1Tag(bytes, at: &offset) == 0x02 else { throw PEMError.invalidASN1 }
        let length = try readASN1Length(bytes, at: &offset)
        guard offset + length <= bytes.count else { throw PEMError.invalidASN1 }
        let value = Array(bytes[offset..<(offset + length)])
        offset += length
        return value
    }

    // MARK: - Helpers

    static func extractDERPayload(pem: String, header: String, footer: String) throws -> Data {
        var body = pem.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        if body.contains("ENCRYPTED") { throw PEMError.encryptedKeyNotSupported }
        guard let headerRange = body.range(of: header),
              let footerRange = body.range(of: footer) else { throw PEMError.invalidPEMStructure }
        let base64 = body[headerRange.upperBound..<footerRange.lowerBound]
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: "")
        guard let data = Data(base64Encoded: base64) else { throw PEMError.invalidPEMStructure }
        return data
    }

    private static func readSSHBytes(_ buf: [UInt8], at offset: inout Int) -> [UInt8]? {
        guard let len = readUInt32(buf, at: &offset) else { return nil }
        let end = offset + Int(len)
        guard end <= buf.count else { return nil }
        let bytes = Array(buf[offset..<end])
        offset = end
        return bytes
    }

    private static func readUInt32(_ buf: [UInt8], at offset: inout Int) -> UInt32? {
        guard offset + 4 <= buf.count else { return nil }
        let value = UInt32(buf[offset]) << 24 | UInt32(buf[offset+1]) << 16 | UInt32(buf[offset+2]) << 8 | UInt32(buf[offset+3])
        offset += 4
        return value
    }

    private static func stripLeadingZeros(_ bytes: [UInt8]) -> [UInt8] {
        var result = bytes
        while result.first == 0 && result.count > 1 { result.removeFirst() }
        return result
    }

    private static func containsSubsequence(_ haystack: [UInt8], _ needle: [UInt8]) -> Bool {
        guard needle.count <= haystack.count else { return false }
        for i in 0...(haystack.count - needle.count) {
            if haystack[i..<(i + needle.count)].elementsEqual(needle) { return true }
        }
        return false
    }
}
