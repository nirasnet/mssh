import Foundation
import Citadel
import NIOSSH
import NIO
import Crypto
import SwiftData

// MARK: - Host Key Prompt Types

enum HostKeyPromptType: Sendable {
    case newHost(fingerprint: String, keyType: String)
    case changedKey(oldFingerprint: String, newFingerprint: String, keyType: String)
}

enum HostKeyPromptResult: Sendable {
    case accept
    case reject
}

// MARK: - TOFU Validator Delegate

/// Implement NIOSSHClientServerAuthenticationDelegate to plug into Citadel's
/// `SSHHostKeyValidator.custom(_:)` pipeline.
final class TOFUHostKeyValidator: NIOSSHClientServerAuthenticationDelegate, @unchecked Sendable {
    private let host: String
    private let port: Int
    private let modelContainer: ModelContainer
    private let promptHandler: @Sendable (HostKeyPromptType) async -> HostKeyPromptResult

    init(
        host: String,
        port: Int,
        modelContainer: ModelContainer,
        promptHandler: @escaping @Sendable (HostKeyPromptType) async -> HostKeyPromptResult
    ) {
        self.host = host
        self.port = port
        self.modelContainer = modelContainer
        self.promptHandler = promptHandler
    }

    func validateHostKey(
        hostKey: NIOSSHPublicKey,
        validationCompletePromise: EventLoopPromise<Void>
    ) {
        // Serialize the presented key to raw bytes via ByteBuffer
        let presentedKeyData = Self.serializePublicKey(hostKey)
        let presentedFingerprint = Self.sha256Fingerprint(of: presentedKeyData)
        let keyType = Self.keyTypeString(for: hostKey)

        let host = self.host
        let port = self.port
        let container = self.modelContainer
        let promptHandler = self.promptHandler

        // Do all the async work off the event loop, then resolve the promise
        Task {
            do {
                let result = try await Self.evaluate(
                    host: host,
                    port: port,
                    presentedKeyData: presentedKeyData,
                    presentedFingerprint: presentedFingerprint,
                    keyType: keyType,
                    container: container,
                    promptHandler: promptHandler
                )
                switch result {
                case .accept:
                    validationCompletePromise.succeed(())
                case .reject:
                    validationCompletePromise.fail(HostKeyValidationError.rejected)
                }
            } catch {
                validationCompletePromise.fail(error)
            }
        }
    }

    // MARK: - Core Evaluation Logic

    private static func evaluate(
        host: String,
        port: Int,
        presentedKeyData: Data,
        presentedFingerprint: String,
        keyType: String,
        container: ModelContainer,
        promptHandler: @Sendable (HostKeyPromptType) async -> HostKeyPromptResult
    ) async throws -> HostKeyPromptResult {
        let context = ModelContext(container)
        let identifier = "\(host):\(port)"

        let descriptor = FetchDescriptor<KnownHost>(
            predicate: #Predicate { $0.hostIdentifier == identifier }
        )
        let matches = try context.fetch(descriptor)

        if let existing = matches.first {
            // We have a stored key for this host
            if existing.publicKeyData == presentedKeyData {
                // Key matches -- TOFU success, update last-seen
                existing.lastSeenAt = Date()
                try context.save()
                return .accept
            } else {
                // KEY CHANGED -- ask the user
                let oldFingerprint = existing.fingerprintSHA256
                let decision = await promptHandler(
                    .changedKey(
                        oldFingerprint: oldFingerprint,
                        newFingerprint: presentedFingerprint,
                        keyType: keyType
                    )
                )
                if decision == .accept {
                    existing.publicKeyData = presentedKeyData
                    existing.fingerprintSHA256 = presentedFingerprint
                    existing.keyTypeDescription = keyType
                    existing.lastSeenAt = Date()
                    try context.save()

                    // Also update Keychain copy
                    try? KeychainService.saveHostKey(host: host, port: port, keyData: presentedKeyData)
                }
                return decision
            }
        } else {
            // First connection to this host -- ask user to accept
            let decision = await promptHandler(
                .newHost(fingerprint: presentedFingerprint, keyType: keyType)
            )
            if decision == .accept {
                let knownHost = KnownHost(
                    host: host,
                    port: port,
                    keyTypeDescription: keyType,
                    fingerprintSHA256: presentedFingerprint,
                    publicKeyData: presentedKeyData
                )
                context.insert(knownHost)
                try context.save()

                try? KeychainService.saveHostKey(host: host, port: port, keyData: presentedKeyData)
            }
            return decision
        }
    }

    // MARK: - Helpers

    static func serializePublicKey(_ key: NIOSSHPublicKey) -> Data {
        var buffer = ByteBufferAllocator().buffer(capacity: 256)
        key.write(to: &buffer)
        return Data(buffer.readableBytesView)
    }

    static func sha256Fingerprint(of data: Data) -> String {
        let digest = SHA256.hash(data: data)
        let base64 = Data(digest).base64EncodedString()
        return "SHA256:\(base64)"
    }

    static func keyTypeString(for key: NIOSSHPublicKey) -> String {
        // The serialized SSH public key format starts with a 4-byte length
        // followed by the key type string (e.g., "ssh-ed25519").
        let data = serializePublicKey(key)
        guard data.count >= 4 else { return "unknown" }
        let length = Int(data[0]) << 24 | Int(data[1]) << 16 | Int(data[2]) << 8 | Int(data[3])
        guard data.count >= 4 + length else { return "unknown" }
        let typeData = data[4 ..< 4 + length]
        return String(data: typeData, encoding: .utf8) ?? "unknown"
    }
}

// MARK: - SSHHostKeyValidator convenience

extension SSHHostKeyValidator {
    /// Creates a TOFU (Trust On First Use) host key validator that stores known
    /// host keys in SwiftData / Keychain and prompts the user when a key is new
    /// or has changed.
    static func tofu(
        host: String,
        port: Int,
        modelContainer: ModelContainer,
        promptHandler: @escaping @Sendable (HostKeyPromptType) async -> HostKeyPromptResult
    ) -> SSHHostKeyValidator {
        let validator = TOFUHostKeyValidator(
            host: host,
            port: port,
            modelContainer: modelContainer,
            promptHandler: promptHandler
        )
        return .custom(validator)
    }
}

// MARK: - Errors

enum HostKeyValidationError: LocalizedError {
    case rejected

    var errorDescription: String? {
        switch self {
        case .rejected:
            return "Host key was rejected by the user."
        }
    }
}
