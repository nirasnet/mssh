import Foundation
import SwiftData

@Model
final class ConnectionProfile {
    var label: String
    var host: String
    var port: Int
    var username: String
    var authTypeRaw: String
    var keyID: String?
    var createdAt: Date
    var lastConnectedAt: Date?

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
    }
}
