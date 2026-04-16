import Foundation
import SwiftData

/// A persisted port-forwarding rule attached to a `ConnectionProfile`. The
/// link is via `profileSyncID` (matching `ConnectionProfile.syncID`) so the
/// rules survive cross-device sync without depending on `persistentModelID`.
///
/// Only `kind == "local"` is supported by the runtime today; the field is
/// stored as a String so adding remote / dynamic forwarding later does not
/// require a SwiftData migration.
@Model
final class PortForward {
    /// Stable identifier for cross-device sync.
    var syncID: String = UUID().uuidString

    /// Owner profile's `syncID`.
    var profileSyncID: String = ""

    /// "local" today; reserved values: "remote", "dynamic".
    var kind: String = "local"

    /// Local-side bind host. Defaults to the loopback so the forward is not
    /// inadvertently exposed to other devices on the network.
    var localHost: String = "127.0.0.1"

    var localPort: Int = 0
    var remoteHost: String = ""
    var remotePort: Int = 0

    /// User-controlled enable/disable. Defaults to true so creating a rule
    /// auto-arms it on the next connection attempt.
    var enabled: Bool = true

    var createdAt: Date = Date()

    init(
        profileSyncID: String,
        kind: String = "local",
        localHost: String = "127.0.0.1",
        localPort: Int,
        remoteHost: String,
        remotePort: Int,
        enabled: Bool = true
    ) {
        self.syncID = UUID().uuidString
        self.profileSyncID = profileSyncID
        self.kind = kind
        self.localHost = localHost
        self.localPort = localPort
        self.remoteHost = remoteHost
        self.remotePort = remotePort
        self.enabled = enabled
        self.createdAt = Date()
    }
}
