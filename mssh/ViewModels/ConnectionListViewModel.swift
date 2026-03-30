import Foundation
import SwiftData
import Observation

@Observable
final class ConnectionListViewModel {
    var searchText = ""

    func saveConnection(
        profile: ConnectionProfile?,
        label: String,
        host: String,
        port: Int,
        username: String,
        authType: AuthenticationType,
        password: String?,
        keyID: String?,
        modelContext: ModelContext
    ) {
        let target: ConnectionProfile
        if let existing = profile {
            target = existing
            target.label = label
            target.host = host
            target.port = port
            target.username = username
            target.authType = authType
            target.keyID = keyID
        } else {
            target = ConnectionProfile(
                label: label,
                host: host,
                port: port,
                username: username,
                authType: authType,
                keyID: keyID
            )
            modelContext.insert(target)
        }

        // Save password to keychain if using password auth
        if authType == .password, let password, !password.isEmpty {
            try? KeychainService.savePassword(
                for: target.persistentModelID.hashValue.description,
                password: password
            )
        }
    }
}
