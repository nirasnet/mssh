import Foundation
import SwiftData

extension Notification.Name {
    /// Broadcast by the iOS keyboard accessory bar (which can't present
    /// SwiftUI sheets directly). The active `TerminalSessionView` listens
    /// for this and shows the snippet picker.
    static let openSnippetPicker = Notification.Name("mssh.openSnippetPicker")
}

/// User-saved command snippet (e.g. "tail -f /var/log/syslog"). Triggered
/// from the terminal accessory bar and pushed to the active SSH session via
/// `SSHTerminalBridge.sendToSSH`.
@Model
final class Snippet {
    /// Stable identifier for cross-device sync.
    var syncID: String = UUID().uuidString

    var label: String = ""
    var command: String = ""
    var createdAt: Date = Date()
    var lastUsedAt: Date? = nil
    var useCount: Int = 0

    init(label: String, command: String) {
        self.label = label
        self.command = command
        self.createdAt = Date()
        self.syncID = UUID().uuidString
    }
}
