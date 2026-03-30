import Foundation
import Citadel
import NIO
import NIOSSH
import Crypto

final class SSHService {
    private var client: SSHClient?

    var isConnected: Bool {
        client != nil
    }

    func connect(
        host: String,
        port: Int,
        username: String,
        authMethod: SSHAuthMethod
    ) async throws -> SSHClient {
        let citadelAuth = authMethod.toCitadel(username: username)
        let client = try await SSHClient.connect(
            host: host,
            port: port,
            authenticationMethod: citadelAuth,
            hostKeyValidator: .acceptAnything(),
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
            // Ed25519 raw keys are 32 bytes
            if keyData.count == 32,
               let privateKey = try? Curve25519.Signing.PrivateKey(rawRepresentation: keyData) {
                return .ed25519(username: username, privateKey: privateKey)
            }
            // Try P256
            if let privateKey = try? P256.Signing.PrivateKey(rawRepresentation: keyData) {
                return .p256(username: username, privateKey: privateKey)
            }
            // Fallback to password if key parsing fails
            return .passwordBased(username: username, password: "")
        }
    }
}
