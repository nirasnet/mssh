import Foundation
import Citadel
import Observation
import SwiftData

@Observable
@MainActor
final class SessionViewModel: Identifiable {
    let id = UUID()
    let profile: ConnectionProfile
    let bridge = SSHTerminalBridge()

    var title: String
    var isConnected: Bool = false
    var statusMessage: String = "Disconnected"

    /// When non-nil, the UI should present the host key prompt overlay.
    var pendingHostKeyPrompt: HostKeyPromptType?

    private let sshService = SSHService()
    private(set) var client: SSHClient?
    private var hostKeyPromptContinuation: CheckedContinuation<HostKeyPromptResult, Never>?

    /// Public accessor for the SSH client, used by SFTP browser
    var sshClient: SSHClient? { client }

    /// The SwiftData model container, injected before calling connect().
    var modelContainer: ModelContainer?

    init(profile: ConnectionProfile) {
        self.profile = profile
        self.title = profile.label
        bridge.onStateChange = { [weak self] connected, status in
            self?.isConnected = connected
            self?.statusMessage = status
        }
    }

    func connect() async {
        guard let modelContainer else {
            statusMessage = "Internal error: missing model container."
            return
        }

        statusMessage = "Connecting..."

        do {
            let authMethod = resolveAuthMethod()

            let client = try await sshService.connect(
                host: profile.host,
                port: profile.port,
                username: profile.username,
                authMethod: authMethod,
                modelContainer: modelContainer,
                hostKeyPrompt: { [weak self] promptType in
                    guard let self else { return .reject }
                    return await self.requestHostKeyDecision(promptType)
                }
            )
            self.client = client

            // Update last connected timestamp
            profile.lastConnectedAt = Date()

            // Start terminal session with default size (will resize on layout)
            bridge.connect(client: client, cols: 80, rows: 24)
        } catch {
            statusMessage = "Connection failed: \(error.localizedDescription)"
        }
    }

    func disconnect() {
        bridge.disconnect()
        Task {
            await sshService.disconnect()
        }
    }

    // MARK: - Host Key Prompt

    /// Called from the validator's background task. Suspends until the user
    /// taps Accept or Reject in the UI.
    @MainActor
    private func requestHostKeyDecision(_ promptType: HostKeyPromptType) async -> HostKeyPromptResult {
        return await withCheckedContinuation { continuation in
            self.hostKeyPromptContinuation = continuation
            self.pendingHostKeyPrompt = promptType
        }
    }

    /// Called by the view when the user taps "Trust" / "Trust Anyway".
    func acceptHostKey() {
        pendingHostKeyPrompt = nil
        hostKeyPromptContinuation?.resume(returning: .accept)
        hostKeyPromptContinuation = nil
    }

    /// Called by the view when the user taps "Reject".
    func rejectHostKey() {
        pendingHostKeyPrompt = nil
        hostKeyPromptContinuation?.resume(returning: .reject)
        hostKeyPromptContinuation = nil
    }

    // MARK: - Private

    private func resolveAuthMethod() -> SSHAuthMethod {
        switch profile.authType {
        case .password:
            let password = KeychainService.getPassword(for: profile.syncID) ?? ""
            return .password(password)
        case .key:
            if let keyID = profile.keyID,
               let keyData = KeychainService.getPrivateKey(id: keyID) {
                return .privateKey(keyData)
            }
            return .password("")
        }
    }
}
