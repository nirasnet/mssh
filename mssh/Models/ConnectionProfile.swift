import Foundation
import SwiftData
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

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

    /// Pinned to a top "Favorites" section in the connection list. Defaults to
    /// false so existing rows migrate without prompting.
    var isFavorite: Bool = false

    /// Optional grouping for the connection list (e.g. "Production",
    /// "Personal"). nil means the profile lives in the catch-all "Other"
    /// section. Free-form so users can invent group names on the fly.
    var groupName: String? = nil

    /// Optional accent color tag — name from `ConnectionProfile.tagPalette`
    /// (e.g. "blue", "green", "orange"). nil means no tag, render with the
    /// default app accent.
    var colorTag: String? = nil

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
        keyID: String? = nil,
        isFavorite: Bool = false,
        groupName: String? = nil,
        colorTag: String? = nil
    ) {
        self.label = label
        self.host = host
        self.port = port
        self.username = username
        self.authTypeRaw = authType.rawValue
        self.keyID = keyID
        self.createdAt = Date()
        self.syncID = UUID().uuidString
        self.isFavorite = isFavorite
        self.groupName = groupName
        self.colorTag = colorTag
        #if os(iOS)
        self.deviceName = UIDevice.current.name
        #elseif os(macOS)
        self.deviceName = Host.current().localizedName ?? "Mac"
        #else
        self.deviceName = "Unknown"
        #endif
    }
}

extension ConnectionProfile {
    /// Curated palette of accent colors for the optional `colorTag` field.
    /// Stored as the lowercase color name; resolved to a SwiftUI `Color` via
    /// `tagColor(named:)`. Centralised so the picker and rendering stay in sync.
    static let tagPalette: [String] = [
        "red", "orange", "yellow", "green", "teal", "blue", "indigo", "purple", "pink"
    ]
}
