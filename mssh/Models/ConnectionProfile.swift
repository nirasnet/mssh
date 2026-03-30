import Foundation
import SwiftData
import UIKit

@Model
final class ConnectionProfile {
    var label: String = ""
    var host: String = ""
    var port: Int = 22
    var username: String = "root"
    var authTypeRaw: String = "password"
    var keyID: String? = nil
    var createdAt: Date = Date()
    var lastConnectedAt: Date? = nil

    /// Stable identifier for cross-device sync. Stays the same across all devices.
    var syncID: String = UUID().uuidString

    /// Name of the device that originally created this profile.
    var deviceName: String = ""

    var authType: AuthenticationType {
        get { AuthenticationType(rawValue: authTypeRaw) ?? .password }
        set { authTypeRaw = newValue.rawValue }
    }

    init(
        label: String,
        host: String,
        port: Int = 22,
        username: String = "root",
        authType: AuthenticationType = .password,
        keyID: String? = nil
    ) {
        self.label = label
        self.host = host
        self.port = port
        self.username = username
        self.authTypeRaw = authType.rawValue
        self.keyID = keyID
        self.createdAt = Date()
        self.syncID = UUID().uuidString
        #if os(iOS)
        self.deviceName = UIDevice.current.name
        #elseif os(macOS)
        self.deviceName = Host.current().localizedName ?? "Mac"
        #else
        self.deviceName = "Unknown"
        #endif
    }
}
