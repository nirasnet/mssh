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
    /// The `hostKeyPrompt` closure is called on the first connection (new key)
    /// or when the stored key does not match (changed key). It receives the
    /// prompt type and must return `.accept` or `.reject`.
    func connect(
        host: String,
        port: Int,
        username: String,
        authMethod: SSHAuthMethod,
        modelContainer: ModelContainer,
        hostKeyPrompt: @escaping @Sendable (HostKeyPromptType) async -> HostKeyPromptResult
    ) async throws -> SSHClient {
        let citadelAuth = authMethod.toCitadel(username: username)

        let validator = SSHHostKeyValidator.tofu(
            host: host,
            port: port,
            modelContainer: modelContainer,
            promptHandler: hostKeyPrompt
        )

        let client = try await SSHClient.connect(
            host: host,
            port: port,
            authenticationMethod: citadelAuth,
            hostKeyValidator: validator,
            reconnect: .never
        )
        self.client = client
        return client
    }

    func disconnect() async {
        try? await client?.close()
        client = nil
    }
}

enum SSHAuthMethod {
    case password(String)
    case privateKey(Data)
}

extension SSHAuthMethod {
    func toCitadel(username: String) -> SSHAuthenticationMethod {
        switch self {
        case .password(let password):
            return .passwordBased(username: username, password: password)

        case .privateKey(let keyData):
            // 1. Ed25519 raw keys are exactly 32 bytes
            if keyData.count == 32,
               let privateKey = try? Curve25519.Signing.PrivateKey(rawRepresentation: keyData) {
                return .ed25519(username: username, privateKey: privateKey)
            }

            // 2. Try PEM-encoded keys (RSA, Ed25519, ECDSA)
            if let pemString = String(data: keyData, encoding: .utf8) {
                if let result = try? parsePEMKey(pemString: pemString, username: username) {
                    return result
                }
            }

            // 3. Try raw EC keys (P256 / P384 / P521) as last resort
            if let pk = try? P256.Signing.PrivateKey(rawRepresentation: keyData) {
                return .p256(username: username, privateKey: pk)
            }
            if let pk = try? P384.Signing.PrivateKey(rawRepresentation: keyData) {
                return .p384(username: username, privateKey: pk)
            }
            if let pk = try? P521.Signing.PrivateKey(rawRepresentation: keyData) {
                return .p521(username: username, privateKey: pk)
            }

            // Fallback -- nothing matched
            return .passwordBased(username: username, password: "")
        }
    }

    /// Attempt to parse a PEM string into the appropriate Citadel auth method.
    private func parsePEMKey(pemString: String, username: String) throws -> SSHAuthenticationMethod? {
        let keyType = PEMParser.detectKeyType(pem: pemString)

        switch keyType {
        case "rsa":
            // Parse RSA components and construct key
            if let components = try? PEMParser.parseRSAComponents(pemString: pemString) {
                // Use Insecure.RSA.PrivateKey with raw components
                // For now, RSA keys in OpenSSH format work best
                // PKCS#1/PKCS#8 require BoringSSL which isn't directly accessible
                break // Fall through to password fallback for non-OpenSSH RSA
            }

        case "ed25519":
            // OpenSSH-format ed25519 key
            if pemString.contains("BEGIN OPENSSH PRIVATE KEY"),
               let rawKey = try PEMParser.parseOpenSSHEd25519(pemString: pemString),
               let pk = try? Curve25519.Signing.PrivateKey(rawRepresentation: rawKey) {
                return .ed25519(username: username, privateKey: pk)
            }
            // PKCS#8 ed25519 -- Apple CryptoKit can handle the DER
            if pemString.contains("BEGIN PRIVATE KEY"),
               let derData = extractPKCS8DER(pem: pemString),
               let pk = try? Curve25519.Signing.PrivateKey(rawRepresentation: derData) {
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

    /// Quick helper to base64-decode the payload of a PKCS#8 PEM.
    private func extractPKCS8DER(pem: String) -> Data? {
        let header = "-----BEGIN PRIVATE KEY-----"
        let footer = "-----END PRIVATE KEY-----"
        guard let hRange = pem.range(of: header),
              let fRange = pem.range(of: footer) else { return nil }
        let base64 = pem[hRange.upperBound..<fRange.lowerBound]
            .replacingOccurrences(of: "\n", with: "")
            .replacingOccurrences(of: "\r", with: "")
        return Data(base64Encoded: base64)
    }
}
