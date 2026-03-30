import Foundation
import Citadel
import Observation

@Observable
@MainActor
final class SessionViewModel: Identifiable {
    let id = UUID()
    let profile: ConnectionProfile
    let bridge = SSHTerminalBridge()

    var title: String
    var isConnected: Bool { bridge.isConnected }
    var statusMessage: String { bridge.statusMessage }

    private let sshService = SSHService()
    private var client: SSHClient?

    init(profile: ConnectionProfile) {
        self.profile = profile
        self.title = profile.label
    }

    func connect() async {
        do {
            // Resolve credentials
            let authMethod = resolveAuthMethod()

            let client = try await sshService.connect(
                host: profile.host,
                port: profile.port,
                username: profile.username,
                authMethod: authMethod
            )
            self.client = client

            // Update last connected timestamp
            profile.lastConnectedAt = Date()

            // Start terminal session with default size (will resize on layout)
            bridge.connect(client: client, cols: 80, rows: 24)
        } catch {
            bridge.statusMessage = "Connection failed: \(error.localizedDescription)"
        }
    }

    func disconnect() {
        bridge.disconnect()
        Task {
            await sshService.disconnect()
        }
    }

    private func resolveAuthMethod() -> SSHAuthMethod {
        switch profile.authType {
        case .password:
            let password = KeychainService.getPassword(for: profile.persistentModelID.hashValue.description) ?? ""
            return .password(password)
        case .key:
            if let keyID = profile.keyID,
               let keyData = KeychainService.getPrivateKey(id: keyID) {
                return .privateKey(keyData, passphrase: nil)
            }
            return .password("")
        }
    }
}
