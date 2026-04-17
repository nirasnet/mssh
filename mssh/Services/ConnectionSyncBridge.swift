import Foundation
import SwiftData

/// Lightweight cross-device connection sync via `NSUbiquitousKeyValueStore`
/// (iCloud key-value storage). Works on ALL Apple platforms without CloudKit
/// — data syncs within ~15 s across devices on the same Apple ID.
///
/// Used primarily for the Mac target where SwiftData+CloudKit is disabled
/// due to a macOS 26.3 SwiftUI layout crash. iOS/iPadOS can also use this
/// as a fallback or supplement to CloudKit.
///
/// Storage format: JSON array of `SyncableConnection` under the key
/// `"mssh.syncedConnections"`. Max 1 MB total for all KVS keys combined —
/// plenty for hundreds of connection profiles (~200 bytes each).
enum ConnectionSyncBridge {
    private static let kvs = NSUbiquitousKeyValueStore.default
    private static let connectionsKey = "mssh.syncedConnections"
    private static let snippetsKey = "mssh.syncedSnippets"
    private static let keysKey = "mssh.syncedKeys"

    // MARK: - Push (export to iCloud KVS)

    /// Serialize all local ConnectionProfiles + Snippets to iCloud KVS.
    /// Call from any device that has data to share.
    @MainActor
    static func push(modelContext: ModelContext) -> (connections: Int, snippets: Int, keys: Int) {
        var connectionCount = 0
        var snippetCount = 0

        if let profiles = try? modelContext.fetch(FetchDescriptor<ConnectionProfile>()) {
            let syncable = profiles.map { SyncableConnection(from: $0) }
            if let data = try? JSONEncoder().encode(syncable) {
                kvs.set(data, forKey: connectionsKey)
                connectionCount = syncable.count
            }
        }

        if let snippets = try? modelContext.fetch(FetchDescriptor<Snippet>()) {
            let syncable = snippets.map { SyncableSnippet(from: $0) }
            if let data = try? JSONEncoder().encode(syncable) {
                kvs.set(data, forKey: snippetsKey)
                snippetCount = syncable.count
            }
        }

        var keyCount = 0
        if let keys = try? modelContext.fetch(FetchDescriptor<SSHKey>()) {
            let syncable = keys.map { SyncableKey(from: $0) }
            if let data = try? JSONEncoder().encode(syncable) {
                kvs.set(data, forKey: keysKey)
                keyCount = syncable.count
            }
        }

        kvs.synchronize()
        return (connectionCount, snippetCount, keyCount)
    }

    // MARK: - Pull (import from iCloud KVS)

    /// Read ConnectionProfiles + Snippets from iCloud KVS and merge into
    /// the local SwiftData store. De-duplicates by syncID so running pull
    /// multiple times is safe.
    @MainActor
    static func pull(modelContext: ModelContext) -> (connections: Int, snippets: Int, keys: Int) {
        kvs.synchronize()
        var newConnections = 0
        var newSnippets = 0
        var newKeys = 0

        // -- Connections --
        if let data = kvs.data(forKey: connectionsKey),
           let remote = try? JSONDecoder().decode([SyncableConnection].self, from: data) {
            let existing = (try? modelContext.fetch(FetchDescriptor<ConnectionProfile>())) ?? []
            let existingSyncIDs = Set(existing.map { $0.syncID })

            for item in remote where !existingSyncIDs.contains(item.syncID) {
                let profile = ConnectionProfile(
                    label: item.label,
                    host: item.host,
                    port: item.port,
                    username: item.username,
                    authType: AuthenticationType(rawValue: item.authTypeRaw) ?? .password,
                    keyID: item.keyID,
                    isFavorite: item.isFavorite,
                    groupName: item.groupName,
                    colorTag: item.colorTag
                )
                // Preserve the original syncID so future pulls don't duplicate.
                profile.syncID = item.syncID
                modelContext.insert(profile)
                newConnections += 1
            }
        }

        // -- Snippets --
        if let data = kvs.data(forKey: snippetsKey),
           let remote = try? JSONDecoder().decode([SyncableSnippet].self, from: data) {
            let existing = (try? modelContext.fetch(FetchDescriptor<Snippet>())) ?? []
            let existingSyncIDs = Set(existing.map { $0.syncID })

            for item in remote where !existingSyncIDs.contains(item.syncID) {
                let snippet = Snippet(label: item.label, command: item.command)
                snippet.syncID = item.syncID
                snippet.useCount = item.useCount
                modelContext.insert(snippet)
                newSnippets += 1
            }
        }

        // -- Keys --
        if let data = kvs.data(forKey: keysKey),
           let remote = try? JSONDecoder().decode([SyncableKey].self, from: data) {
            let existing = (try? modelContext.fetch(FetchDescriptor<SSHKey>())) ?? []
            let existingSyncIDs = Set(existing.map { $0.syncID })

            for item in remote where !existingSyncIDs.contains(item.syncID) {
                let key = SSHKey(
                    label: item.label,
                    keyType: item.keyType,
                    keychainID: item.keychainID,
                    publicKeyText: item.publicKeyText,
                    syncAcrossDevices: item.syncAcrossDevices
                )
                key.syncID = item.syncID
                modelContext.insert(key)
                newKeys += 1
            }
        }

        if newConnections > 0 || newSnippets > 0 || newKeys > 0 {
            try? modelContext.save()
        }
        return (newConnections, newSnippets, newKeys)
    }
}

// MARK: - Codable transfer types

private struct SyncableConnection: Codable {
    let syncID: String
    let label: String
    let host: String
    let port: Int
    let username: String
    let authTypeRaw: String
    let keyID: String?
    let isFavorite: Bool
    let groupName: String?
    let colorTag: String?

    init(from profile: ConnectionProfile) {
        self.syncID = profile.syncID
        self.label = profile.label
        self.host = profile.host
        self.port = profile.port
        self.username = profile.username
        self.authTypeRaw = profile.authTypeRaw
        self.keyID = profile.keyID
        self.isFavorite = profile.isFavorite
        self.groupName = profile.groupName
        self.colorTag = profile.colorTag
    }
}

private struct SyncableSnippet: Codable {
    let syncID: String
    let label: String
    let command: String
    let useCount: Int

    init(from snippet: Snippet) {
        self.syncID = snippet.syncID
        self.label = snippet.label
        self.command = snippet.command
        self.useCount = snippet.useCount
    }
}

private struct SyncableKey: Codable {
    let syncID: String
    let label: String
    let keyType: String
    let keychainID: String
    let publicKeyText: String
    let syncAcrossDevices: Bool

    init(from key: SSHKey) {
        self.syncID = key.syncID
        self.label = key.label
        self.keyType = key.keyType
        self.keychainID = key.keychainID
        self.publicKeyText = key.publicKeyText
        self.syncAcrossDevices = key.syncAcrossDevices
    }
}
