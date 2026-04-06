import Foundation
import SwiftData

@Model
final class KnownHost {
    var hostIdentifier: String
    var host: String
    var port: Int
    var keyTypeDescription: String
    var fingerprintSHA256: String
    var publicKeyData: Data
    var firstSeenAt: Date
    var lastSeenAt: Date

    init(
        host: String,
        port: Int,
        keyTypeDescription: String,
        fingerprintSHA256: String,
        publicKeyData: Data
    ) {
        self.hostIdentifier = "\(host):\(port)"
        self.host = host
        self.port = port
        self.keyTypeDescription = keyTypeDescription
        self.fingerprintSHA256 = fingerprintSHA256
        self.publicKeyData = publicKeyData
        self.firstSeenAt = Date()
        self.lastSeenAt = Date()
    }
}
