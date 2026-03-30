import Foundation
import Citadel
import NIO
import NIOSSH

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
        let client = try await SSHClient.connect(
            host: host,
            port: port,
            authenticationMethod: authMethod,
            hostKeyValidator: .acceptAnything(), // TODO: replace with proper TOFU validation
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
    case privateKey(Data, passphrase: String?)
}

extension SSHAuthMethod {
    func toCitadel(username: String) -> Citadel.SSHAuthenticationMethod {
        switch self {
        case .password(let password):
            return .passwordBased(username: username, password: password)
        case .privateKey(let pemData, let passphrase):
            let pemString = String(data: pemData, encoding: .utf8) ?? ""
            if let passphrase {
                return .rsa(username: username, privateKey: .init(sshRsa: pemString), password: passphrase)
            } else {
                return .rsa(username: username, privateKey: .init(sshRsa: pemString))
            }
        }
    }
}
