import Foundation
import Citadel
import SwiftData

/// Manages SSH port-forwarding rules for an active session.
///
/// **Status:** This is a non-blocking stub. Citadel's `SSHClient` does not
/// (as of 0.12.x) expose a public, stable API for arbitrary
/// direct-tcpip channels with a Network.framework listener — wiring full
/// local forwarding requires either patching Citadel or building a
/// dedicated NIO bootstrap. To avoid blocking the rest of the renovation,
/// `start(forward:on:)` records its intent and returns `.notSupported` so
/// the UI surfaces a friendly status without the SSH session ever failing.
///
/// The model + UI are deliberately complete so the manager can be filled in
/// later without further schema migrations.
@MainActor
final class PortForwardManager {
    enum ForwardError: LocalizedError {
        case notSupported(reason: String)

        var errorDescription: String? {
            switch self {
            case .notSupported(let reason):
                return "Port forwarding not yet active: \(reason)"
            }
        }
    }

    func startAll(for profile: ConnectionProfile, on client: SSHClient, modelContext: ModelContext) -> [ForwardError] {
        let profileID = profile.syncID
        let predicate = #Predicate<PortForward> { fwd in
            fwd.profileSyncID == profileID && fwd.enabled
        }
        let descriptor = FetchDescriptor<PortForward>(predicate: predicate)

        guard let forwards = try? modelContext.fetch(descriptor), !forwards.isEmpty else {
            return []
        }

        return forwards.compactMap { fwd in
            switch start(forward: fwd, on: client) {
            case .success: return nil
            case .failure(let error): return error
            }
        }
    }

    func start(forward: PortForward, on client: SSHClient) -> Result<Void, ForwardError> {
        // Intentionally fail soft: persistent rule + clear UI message rather
        // than a partial implementation that pretends to work.
        // TODO: when real forwarding lands, replace with a NIO bootstrap +
        // direct-tcpip channel and track the handle for stopAll().
        return .failure(.notSupported(
            reason: "needs Citadel direct-tcpip wiring — rule saved for when the runtime lands"
        ))
    }

    func stopAll(for profile: ConnectionProfile) {
        // No real listeners to tear down today; this is a hook for the
        // future runtime so callers don't need to change once it lands.
    }
}
