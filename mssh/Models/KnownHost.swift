import Foundation
import SwiftData

@Model
final class KnownHost {
    // Inline defaults on every stored property are required for
    // NSPersistentCloudKitContainer compatibility — otherwise container init
    // crashes with "attributes must be optional or have a default value".
    var hostIdentifier: String = ""
    var host: String = ""
    var port: Int = 22
    var keyTypeDescription: String = ""
    var fingerprintSHA256: String = ""
    var publicKeyData: Data = Data()
    var firstSeenAt: Date = Date()
    var lastSeenAt: Date = Date()

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
