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

    /// Number of connection attempts (for retry logic)
    var connectionAttempts: Int = 0

    private let sshService = SSHService()
    private let portForwardManager = PortForwardManager()
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

        connectionAttempts += 1
        statusMessage = "Connecting..."

        let authMethod: SSHAuthMethod
        do {
            authMethod = try resolveAuthMethod()
        } catch let resolutionError as AuthResolutionError {
            // Pre-flight failure (e.g. key not on this device) — never attempt
            // the SSH handshake, otherwise the server's generic
            // "key authentication failed" overwrites our explanation.
            statusMessage = resolutionError.errorDescription ?? "Authentication unavailable."
            return
        } catch {
            statusMessage = "Authentication setup failed: \(error.localizedDescription)"
            return
        }

        do {
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

            // Reset attempt counter on success
            connectionAttempts = 0

            // Start port forwards (non-blocking — failures surface as a
            // status message but never abort the SSH session).
            if let container = self.modelContainer {
                let errors = portForwardManager.startAll(
                    for: profile,
                    on: client,
                    modelContext: container.mainContext
                )
                if let firstError = errors.first {
                    statusMessage = firstError.errorDescription ?? "Port forward failed"
                }
            }

            // Start terminal session with default size (will resize on layout)
            bridge.connect(client: client, cols: 80, rows: 24)
        } catch let error as SSHConnectionError {
            statusMessage = "Connection failed: \(error.localizedDescription)"
        } catch let error as KeyParseError {
            // Surface verbatim — the message already includes the conversion
            // command. No "Connection failed:" prefix, since the failure was
            // before the connection attempt.
            statusMessage = error.errorDescription ?? "Could not parse private key."
        } catch {
            // Provide user-friendly error messages
            let friendlyMessage = friendlyErrorMessage(error)
            statusMessage = "Connection failed: \(friendlyMessage)"
        }
    }

    func disconnect() {
        bridge.disconnect()
        portForwardManager.stopAll(for: profile)
        // If a host key prompt is pending, reject it so the continuation
        // does not hang indefinitely.
        if hostKeyPromptContinuation != nil {
            rejectHostKey()
        }
        client = nil
        Task {
            await sshService.disconnect()
        }
    }

    // MARK: - Host Key Prompt

    @MainActor
    private func requestHostKeyDecision(_ promptType: HostKeyPromptType) async -> HostKeyPromptResult {
        return await withCheckedContinuation { continuation in
            self.hostKeyPromptContinuation = continuation
            self.pendingHostKeyPrompt = promptType
        }
    }

    func acceptHostKey() {
        pendingHostKeyPrompt = nil
        hostKeyPromptContinuation?.resume(returning: .accept)
        hostKeyPromptContinuation = nil
    }

    func rejectHostKey() {
        pendingHostKeyPrompt = nil
        hostKeyPromptContinuation?.resume(returning: .reject)
        hostKeyPromptContinuation = nil
    }

    // MARK: - Private

    private func resolveAuthMethod() throws -> SSHAuthMethod {
        switch profile.authType {
        case .password:
            // Try device-local first, then fall back to iCloud Keychain
            let password = KeychainService.getPassword(for: profile.syncID)
                ?? KeychainService.getPasswordSyncable(for: profile.syncID)
                ?? ""
            return .password(password)
        case .key:
            if let keyData = lookupPrivateKeyForProfile() {
                return .privateKey(keyData)
            }
            // Key isn't on this device — surface a clear, actionable error
            // and DO NOT proceed with the SSH attempt (otherwise the server's
            // generic "key authentication failed" overwrites this).
            throw AuthResolutionError.keyMissingOnDevice(profileLabel: profile.label)
        }
    }

    /// Look up the private key bytes for this profile.
    ///
    /// Resolution order (defends against the device-specific keychainID
    /// stored in `ConnectionProfile.keyID`):
    ///   1. Treat `keyID` as a Keychain account suffix — works for keys
    ///      imported on this device.
    ///   2. Treat `keyID` as an `SSHKey.syncID` and look up the matching
    ///      SSHKey row to get the local `keychainID`. Recovers the case
    ///      where the user re-imports the same key on a new device.
    private func lookupPrivateKeyForProfile() -> Data? {
        guard let keyID = profile.keyID, !keyID.isEmpty else { return nil }

        if let data = KeychainService.getPrivateKey(id: keyID) {
            return data
        }

        guard let context = modelContainer?.mainContext else { return nil }
        let predicate = #Predicate<SSHKey> { $0.syncID == keyID || $0.keychainID == keyID }
        let descriptor = FetchDescriptor<SSHKey>(predicate: predicate)
        if let key = try? context.fetch(descriptor).first {
            return KeychainService.getPrivateKey(id: key.keychainID)
        }
        return nil
    }

    /// Convert common errors to user-friendly messages
    private func friendlyErrorMessage(_ error: Error) -> String {
        // Use both localizedDescription and full debug description for matching
        let desc = error.localizedDescription.lowercased()
        let debugDesc = String(describing: error).lowercased()

        // Citadel SSHClientError — these show as "error 0", "error 4", etc.
        // Match by type name since the enum doesn't provide good localizedDescription
        if debugDesc.contains("sshclienterror") {
            if debugDesc.contains("authentication") || debugDesc.contains("error 4") {
                if profile.authType == .key {
                    return "Authentication failed. The server may not accept this key format. Try converting with: ssh-keygen -p -N \"\" -o -f <key>"
                }
                return "Authentication failed. Check your username and password."
            }
            if debugDesc.contains("error 0") {
                return "SSH handshake failed. The server may use unsupported algorithms."
            }
            if debugDesc.contains("error 1") {
                return "SSH protocol error during connection to \(profile.host)."
            }
            if debugDesc.contains("error 2") || debugDesc.contains("error 3") {
                return "SSH session could not be established with \(profile.host)."
            }
            // Generic Citadel error fallback
            return "SSH connection failed. Check that \(profile.host):\(profile.port) is reachable and credentials are correct."
        }

        // NIO/SSH precondition or buffer overflow (Citadel .all bug)
        if debugDesc.contains("precondition") || debugDesc.contains("buffer") || debugDesc.contains("bytebuffer") {
            return "Internal SSH protocol error. Please try reconnecting."
        }

        // Network errors
        if desc.contains("could not connect") || desc.contains("network is unreachable") {
            return "Cannot reach \(profile.host). Check your internet connection."
        }
        if desc.contains("connection refused") {
            return "Connection refused by \(profile.host):\(profile.port). Verify the port is correct and SSH is running."
        }
        if desc.contains("timed out") || desc.contains("timeout") {
            return "Connection timed out. The host may be down or blocked by a firewall."
        }
        if desc.contains("no route to host") {
            return "No route to \(profile.host). Check the hostname or IP address."
        }
        if desc.contains("name or service not known") || desc.contains("nodename nor servname") {
            return "Cannot resolve \(profile.host). Check the hostname."
        }

        // SSH-specific errors
        if desc.contains("authentication") || desc.contains("auth")
            || debugDesc.contains("authentication") || debugDesc.contains("auth") {
            if profile.authType == .key {
                return "Key authentication failed. The server may not accept this key, or the key format is unsupported."
            }
            return "Authentication failed. Check your password."
        }
        if desc.contains("algorithm") || desc.contains("negotiation") || desc.contains("kex")
            || debugDesc.contains("algorithm") || debugDesc.contains("negotiation") || debugDesc.contains("kex") {
            return "Encryption negotiation failed. The server may use algorithms not supported by this client."
        }
        if desc.contains("host key") || desc.contains("rejected") {
            return "Host key verification failed."
        }
        if desc.contains("channel") || debugDesc.contains("channelopen") {
            return "Server rejected the session request."
        }
        if desc.contains("banner") || desc.contains("protocol") || desc.contains("version") {
            return "Not an SSH server, or incompatible SSH protocol version."
        }

        // iOS-specific network issues
        if desc.contains("posix") || desc.contains("errno")
            || debugDesc.contains("posix") || debugDesc.contains("errno") {
            return "Network error connecting to \(profile.host):\(profile.port)."
        }

        // Last resort: if the localizedDescription is unhelpful (e.g. "The operation couldn't be completed")
        // use the debug description which typically has more detail
        if desc.contains("operation couldn") || desc.count < 20 {
            return "Connection to \(profile.host) failed. Verify the host, port, and credentials."
        }

        return error.localizedDescription
    }
}

// MARK: - Auth Resolution Errors

/// Pre-flight authentication failure raised before the SSH handshake. Lets
/// `SessionViewModel.connect()` surface a precise reason (e.g. "key not on
/// device") instead of letting the server respond with a generic
/// "Authentication failed" that overwrites the real diagnosis.
enum AuthResolutionError: LocalizedError {
    case keyMissingOnDevice(profileLabel: String)

    var errorDescription: String? {
        switch self {
        case .keyMissingOnDevice(let label):
            return "Connection failed: the SSH key for \"\(label)\" isn't on this device. Open the Keys tab to import the matching private key, then re-open this connection."
        }
    }
}
