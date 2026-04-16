import Foundation
import Citadel
import NIO
import NIOSSH
import Crypto
import SwiftData

final class SSHService {
    private var client: SSHClient?

    var isConnected: Bool {
        client != nil
    }

    /// Connects to an SSH server using TOFU host key validation.
    /// Includes a connection timeout to prevent hanging on iPhone.
    /// Uses default algorithms to avoid known Citadel .all buffer overflow bug (#76).
    /// If defaults fail, retries with .all as a last resort for maximum server compat.
    func connect(
        host: String,
        port: Int,
        username: String,
        authMethod: SSHAuthMethod,
        modelContainer: ModelContainer,
        hostKeyPrompt: @escaping @Sendable (HostKeyPromptType) async -> HostKeyPromptResult
    ) async throws -> SSHClient {
        let citadelAuth = try authMethod.toCitadel(username: username)

        let validator = SSHHostKeyValidator.tofu(
            host: host,
            port: port,
            modelContainer: modelContainer,
            promptHandler: hostKeyPrompt
        )

        // First attempt: default algorithms (safe, no buffer overflow)
        let connectedClient: SSHClient
        do {
            connectedClient = try await connectWithTimeout(
                host: host,
                port: port,
                authenticationMethod: citadelAuth,
                hostKeyValidator: validator,
                algorithms: nil
            )
        } catch let error as SSHConnectionError {
            throw error
        } catch {
            // Check if this looks like an algorithm negotiation failure
            let errorDesc = String(describing: error).lowercased()
            let isAlgorithmIssue = errorDesc.contains("algorithm")
                || errorDesc.contains("negotiation")
                || errorDesc.contains("kex")
                || errorDesc.contains("no matching")

            if isAlgorithmIssue {
                // Retry with .all for maximum compatibility (risk of buffer overflow on some servers,
                // but better than failing to connect at all)
                do {
                    connectedClient = try await connectWithTimeout(
                        host: host,
                        port: port,
                        authenticationMethod: citadelAuth,
                        hostKeyValidator: validator,
                        algorithms: .all
                    )
                } catch {
                    // .all also failed — throw the original algorithm error which is more informative
                    throw error
                }
            } else {
                throw error
            }
        }

        self.client = connectedClient
        return connectedClient
    }

    /// Connect with a timeout to prevent hanging on mobile networks.
    /// Pass nil for algorithms to use Citadel defaults.
    private func connectWithTimeout(
        host: String,
        port: Int,
        authenticationMethod: SSHAuthenticationMethod,
        hostKeyValidator: SSHHostKeyValidator,
        algorithms: SSHAlgorithms?
    ) async throws -> SSHClient {
        try await withThrowingTaskGroup(of: SSHClient.self) { group in
            group.addTask {
                if let algorithms {
                    return try await SSHClient.connect(
                        host: host,
                        port: port,
                        authenticationMethod: authenticationMethod,
                        hostKeyValidator: hostKeyValidator,
                        reconnect: .never,
                        algorithms: algorithms
                    )
                } else {
                    return try await SSHClient.connect(
                        host: host,
                        port: port,
                        authenticationMethod: authenticationMethod,
                        hostKeyValidator: hostKeyValidator,
                        reconnect: .never
                    )
                }
            }
            group.addTask {
                try await Task.sleep(for: .seconds(15))
                throw SSHConnectionError.timeout(seconds: 15)
            }
            guard let result = try await group.next() else {
                throw SSHConnectionError.timeout(seconds: 15)
            }
            group.cancelAll()
            return result
        }
    }

    func disconnect() async {
        try? await client?.close()
        client = nil
    }
}

// MARK: - Connection Errors

enum SSHConnectionError: LocalizedError {
    case timeout(seconds: Int)

    var errorDescription: String? {
        switch self {
        case .timeout(let seconds):
            return "Connection timed out after \(seconds)s. Check the host address and your network."
        }
    }
}

// MARK: - Auth Methods

enum SSHAuthMethod {
    case password(String)
    case privateKey(Data)
}

enum KeyParseError: LocalizedError {
    case unsupportedFormat(byteCount: Int, headerHint: String?)

    var errorDescription: String? {
        switch self {
        case .unsupportedFormat(let count, let hint):
            let headerLine = hint.map { " Detected header: \($0)." } ?? ""
            return "Could not parse the private key (\(count) bytes).\(headerLine) RSA keys must be in OpenSSH format — convert on your Mac with: ssh-keygen -p -N \"\" -o -f <keyfile>"
        }
    }
}

extension SSHAuthMethod {
    func toCitadel(username: String) throws -> SSHAuthenticationMethod {
        switch self {
        case .password(let password):
            return .passwordBased(username: username, password: password)

        case .privateKey(let keyData):
            // 1. Ed25519 raw keys are exactly 32 bytes (seed)
            if keyData.count == 32,
               let privateKey = try? Curve25519.Signing.PrivateKey(rawRepresentation: keyData) {
                return .ed25519(username: username, privateKey: privateKey)
            }

            // 2. Ed25519 raw keys can be 64 bytes (seed + public key)
            if keyData.count == 64 {
                let seed = keyData.prefix(32)
                if let privateKey = try? Curve25519.Signing.PrivateKey(rawRepresentation: seed) {
                    return .ed25519(username: username, privateKey: privateKey)
                }
            }

            // 3. Try PEM-encoded keys (RSA, Ed25519, ECDSA)
            if let pemString = String(data: keyData, encoding: .utf8) {
                if let result = try? parsePEMKey(pemString: pemString, username: username) {
                    return result
                }
            }

            // 4. Try raw RSA key data directly with Citadel
            if let pemString = String(data: keyData, encoding: .utf8),
               let rsaKey = try? Insecure.RSA.PrivateKey(sshRsa: pemString) {
                return .rsa(username: username, privateKey: rsaKey)
            }

            // 5. Try raw EC keys (P256 / P384 / P521) as last resort
            if let pk = try? P256.Signing.PrivateKey(rawRepresentation: keyData) {
                return .p256(username: username, privateKey: pk)
            }
            if let pk = try? P384.Signing.PrivateKey(rawRepresentation: keyData) {
                return .p384(username: username, privateKey: pk)
            }
            if let pk = try? P521.Signing.PrivateKey(rawRepresentation: keyData) {
                return .p521(username: username, privateKey: pk)
            }

            // Nothing matched — surface a precise error instead of falling
            // back to an empty password (which the server then rejects with
            // a generic "Authentication failed" that hides the real cause).
            let header = String(data: keyData, encoding: .utf8)?
                .components(separatedBy: "\n")
                .first
                .map { String($0.prefix(60)) }
            throw KeyParseError.unsupportedFormat(byteCount: keyData.count, headerHint: header)
        }
    }

    /// Attempt to parse a PEM string into the appropriate Citadel auth method.
    private func parsePEMKey(pemString: String, username: String) throws -> SSHAuthenticationMethod? {
        let keyType = PEMParser.detectKeyType(pem: pemString)

        switch keyType {
        case "rsa":
            // Use Citadel's built-in RSA key parser (supports OpenSSH format)
            if let rsaKey = try? Insecure.RSA.PrivateKey(sshRsa: pemString) {
                return .rsa(username: username, privateKey: rsaKey)
            }
            // PKCS#1 and PKCS#8 RSA keys are not directly supported by Citadel.
            // Users should convert with: ssh-keygen -p -N "" -o -f <keyfile>
            break

        case "ed25519":
            // OpenSSH-format ed25519 key
            if pemString.contains("BEGIN OPENSSH PRIVATE KEY"),
               let rawKey = try PEMParser.parseOpenSSHEd25519(pemString: pemString),
               let pk = try? Curve25519.Signing.PrivateKey(rawRepresentation: rawKey) {
                return .ed25519(username: username, privateKey: pk)
            }
            // PKCS#8 ed25519 -- extract the raw 32-byte seed from ASN.1
            if pemString.contains("BEGIN PRIVATE KEY"),
               let rawKey = extractEd25519FromPKCS8(pem: pemString),
               let pk = try? Curve25519.Signing.PrivateKey(rawRepresentation: rawKey) {
                return .ed25519(username: username, privateKey: pk)
            }

        case "ecdsa-256", "ecdsa":
            if let pk = try? P256.Signing.PrivateKey(pemRepresentation: pemString) {
                return .p256(username: username, privateKey: pk)
            }

        case "ecdsa-384":
            if let pk = try? P384.Signing.PrivateKey(pemRepresentation: pemString) {
                return .p384(username: username, privateKey: pk)
            }

        case "ecdsa-521":
            if let pk = try? P521.Signing.PrivateKey(pemRepresentation: pemString) {
                return .p521(username: username, privateKey: pk)
            }

        default:
            break
        }

        return nil
    }

    /// Extract the raw 32-byte Ed25519 seed from a PKCS#8 DER structure.
    private func extractEd25519FromPKCS8(pem: String) -> Data? {
        let header = "-----BEGIN PRIVATE KEY-----"
        let footer = "-----END PRIVATE KEY-----"
        guard let hRange = pem.range(of: header),
              let fRange = pem.range(of: footer) else { return nil }
        let base64 = pem[hRange.upperBound..<fRange.lowerBound]
            .replacingOccurrences(of: "\n", with: "")
            .replacingOccurrences(of: "\r", with: "")
            .replacingOccurrences(of: " ", with: "")
        guard let derData = Data(base64Encoded: base64) else { return nil }

        // Verify this is an Ed25519 key by finding the OID 1.3.101.112
        let ed25519OID: [UInt8] = [0x06, 0x03, 0x2b, 0x65, 0x70]
        let bytes = Array(derData)
        guard bytes.count > ed25519OID.count else { return nil }

        var foundOID = false
        for i in 0...(bytes.count - ed25519OID.count) {
            if Array(bytes[i..<(i + ed25519OID.count)]) == ed25519OID {
                foundOID = true
                break
            }
        }
        guard foundOID, bytes.count >= 34 else { return nil }

        // The seed is the last 32 bytes of the DER structure
        return Data(bytes[(bytes.count - 32)...])
    }
}
