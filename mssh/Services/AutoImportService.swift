import Foundation
import SwiftData

/// Automatically imports connections and keys from a JSON seed file in iCloud Drive.
/// Looks for `mssh-keys/connections.json` in iCloud Drive on first launch.
enum AutoImportService {

    struct SeedConnection: Codable {
        let label: String
        let host: String
        let port: Int
        let username: String
        let authType: String
        let keyFile: String?
    }

    /// Run auto-import if not already done. Call from app launch.
    @MainActor
    static func importIfNeeded(modelContext: ModelContext) {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: "autoImportComplete") else { return }

        #if os(macOS)
        // On macOS, try to import directly from ~/.ssh/config first
        if importFromSSHConfig(modelContext: modelContext) {
            defaults.set(true, forKey: "autoImportComplete")
            return
        }
        #endif

        // Find the iCloud Drive mssh-keys folder
        guard let iCloudURL = FileManager.default.url(forUbiquityContainerIdentifier: nil)?
            .appendingPathComponent("Documents/mssh-keys") ??
            findICloudDriveMSSHKeys() else {
            return
        }

        print("[mSSH] Auto-import: found mssh-keys at \(iCloudURL.path)")

        let jsonURL = iCloudURL.appendingPathComponent("connections.json")
        guard FileManager.default.fileExists(atPath: jsonURL.path),
              let jsonData = try? Data(contentsOf: jsonURL),
              let seedConnections = try? JSONDecoder().decode([SeedConnection].self, from: jsonData) else {
            print("[mSSH] Auto-import: no connections.json found or failed to parse")
            return
        }
        print("[mSSH] Auto-import: found \(seedConnections.count) connections to import")

        var importedKeys: [String: String] = [:] // keyFile -> keychainID

        // First import all key files
        let keyFiles = (try? FileManager.default.contentsOfDirectory(at: iCloudURL, includingPropertiesForKeys: nil)) ?? []
        for fileURL in keyFiles {
            let name = fileURL.lastPathComponent
            guard name != "connections.json" && name != "config" && !name.hasSuffix(".pub") && !name.hasPrefix(".") else { continue }

            guard let data = try? Data(contentsOf: fileURL),
                  let text = String(data: data, encoding: .utf8),
                  SSHKeyImporter.detectFormat(text) != .unknown else { continue }

            let keychainID = UUID().uuidString
            if let _ = try? KeychainService.savePrivateKey(id: keychainID, pemData: data) {
                importedKeys[name] = keychainID

                let keyType = PEMParser.detectKeyType(pem: text)
                let sshKey = SSHKey(
                    label: name,
                    keyType: keyType,
                    keychainID: keychainID,
                    publicKeyText: "(imported from Mac)"
                )
                modelContext.insert(sshKey)
            }
        }

        // Now create connections
        for seed in seedConnections {
            let keyID = seed.keyFile.flatMap { importedKeys[$0] }
            let authType: AuthenticationType = (seed.authType == "key" && keyID != nil) ? .key : .password

            let profile = ConnectionProfile(
                label: seed.label,
                host: seed.host,
                port: seed.port,
                username: seed.username,
                authType: authType,
                keyID: keyID
            )
            modelContext.insert(profile)
        }

        try? modelContext.save()
        defaults.set(true, forKey: "autoImportComplete")
    }

    #if os(macOS)
    /// On macOS, directly read ~/.ssh/config and import keys from ~/.ssh/
    @MainActor
    private static func importFromSSHConfig(modelContext: ModelContext) -> Bool {
        let fm = FileManager.default
        let sshDir = fm.homeDirectoryForCurrentUser.appendingPathComponent(".ssh")
        let configURL = sshDir.appendingPathComponent("config")

        guard fm.fileExists(atPath: configURL.path),
              let configData = try? Data(contentsOf: configURL),
              let configText = String(data: configData, encoding: .utf8) else {
            print("[mSSH] Auto-import: no ~/.ssh/config found")
            return false
        }

        let entries = SSHConfigParser.parse(configText)
        let hosts = SSHConfigParser.concreteHosts(from: entries)
        guard !hosts.isEmpty else {
            print("[mSSH] Auto-import: no concrete hosts in config")
            return false
        }

        print("[mSSH] Auto-import: found \(hosts.count) hosts in ~/.ssh/config")

        // Import keys referenced by IdentityFile
        var importedKeys: [String: String] = [:] // identityFile path -> keychainID

        for host in hosts {
            let resolved = SSHConfigParser.resolve(host, withDefaults: entries)
            guard let identityFile = resolved.identityFile else { continue }

            // Expand ~ to home directory
            let expandedPath: String
            if identityFile.hasPrefix("~/") {
                expandedPath = fm.homeDirectoryForCurrentUser.path + String(identityFile.dropFirst(1))
            } else {
                expandedPath = identityFile
            }

            guard importedKeys[expandedPath] == nil,
                  fm.fileExists(atPath: expandedPath),
                  let keyData = try? Data(contentsOf: URL(fileURLWithPath: expandedPath)),
                  let keyText = String(data: keyData, encoding: .utf8),
                  SSHKeyImporter.detectFormat(keyText) != .unknown else {
                continue
            }

            let keychainID = UUID().uuidString
            guard (try? KeychainService.savePrivateKey(id: keychainID, pemData: keyData)) != nil else {
                continue
            }

            let keyType = PEMParser.detectKeyType(pem: keyText)
            let keyLabel = URL(fileURLWithPath: expandedPath).lastPathComponent
            let sshKey = SSHKey(
                label: keyLabel,
                keyType: keyType,
                keychainID: keychainID,
                publicKeyText: "(imported from Mac)"
            )
            modelContext.insert(sshKey)
            importedKeys[expandedPath] = keychainID
            print("[mSSH] Auto-import: imported key \(keyLabel)")
        }

        // Create connection profiles
        var count = 0
        for host in hosts {
            let resolved = SSHConfigParser.resolve(host, withDefaults: entries)

            // Match identity file to imported key
            var keyID: String?
            if let identityFile = resolved.identityFile {
                let expandedPath: String
                if identityFile.hasPrefix("~/") {
                    expandedPath = fm.homeDirectoryForCurrentUser.path + String(identityFile.dropFirst(1))
                } else {
                    expandedPath = identityFile
                }
                keyID = importedKeys[expandedPath]
            }

            let profile = ConnectionProfile(
                label: host.hostAlias,
                host: resolved.effectiveHost,
                port: resolved.effectivePort,
                username: resolved.effectiveUser,
                authType: keyID != nil ? .key : .password,
                keyID: keyID
            )
            modelContext.insert(profile)
            count += 1
        }

        try? modelContext.save()
        print("[mSSH] Auto-import: created \(count) connections, \(importedKeys.count) keys")
        return count > 0
    }
    #endif

    private static func findICloudDriveMSSHKeys() -> URL? {
        let fm = FileManager.default

        // Path 1: ~/Library/Mobile Documents/com~apple~CloudDocs/mssh-keys (iOS & macOS)
        let mobileDocsURL = fm.urls(for: .libraryDirectory, in: .userDomainMask).first?
            .appendingPathComponent("Mobile Documents/com~apple~CloudDocs/mssh-keys")
        if let url = mobileDocsURL, fm.fileExists(atPath: url.path) {
            return url
        }

        #if os(macOS)
        // Path 2: Direct home path on macOS (works for non-sandboxed debug builds)
        let homeURL = fm.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs/mssh-keys")
        if fm.fileExists(atPath: homeURL.path) {
            return homeURL
        }
        #endif

        return nil
    }
}
