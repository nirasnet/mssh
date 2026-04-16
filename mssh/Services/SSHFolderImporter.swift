#if os(macOS)
import Foundation
import AppKit
import SwiftData

/// Summary of a single import run — shown to the user after the pass.
struct SSHFolderImportResult: Sendable {
    var keysImported: Int = 0
    var keysSkipped: Int = 0
    var profilesImported: Int = 0
    var profilesSkipped: Int = 0
    var errors: [String] = []

    var isEmpty: Bool {
        keysImported == 0 && profilesImported == 0
    }

    var humanSummary: String {
        var parts: [String] = []
        if keysImported > 0 { parts.append("\(keysImported) key\(keysImported == 1 ? "" : "s") imported") }
        if keysSkipped > 0 { parts.append("\(keysSkipped) already present") }
        if profilesImported > 0 { parts.append("\(profilesImported) connection\(profilesImported == 1 ? "" : "s") imported") }
        if profilesSkipped > 0 { parts.append("\(profilesSkipped) connection\(profilesSkipped == 1 ? "" : "s") already present") }
        if parts.isEmpty { parts.append("Nothing new to import") }
        if !errors.isEmpty { parts.append("\(errors.count) file\(errors.count == 1 ? "" : "s") skipped") }
        return parts.joined(separator: ". ") + "."
    }
}

/// Mac-only importer that pulls private keys + `~/.ssh/config` entries into
/// mSSH's SwiftData store. Because the macOS app is sandboxed it can't read
/// `~/.ssh/` directly — the first run prompts the user via `NSOpenPanel` and
/// we persist a security-scoped bookmark so subsequent launches can import
/// silently in the background.
///
/// Newly-imported keys are flagged `syncAcrossDevices = true` so the
/// user's existing Mac keys propagate to iPhone / iPad via iCloud Keychain
/// immediately.
@MainActor
enum SSHFolderImporter {
    private static let bookmarkKey = "mssh.sshFolderBookmark"
    private static let didPromptKey = "mssh.didPromptSSHFolderImport"

    /// Show the folder picker and import on confirmation. Saves a
    /// security-scoped bookmark for future silent runs.
    @discardableResult
    static func promptAndImport(modelContext: ModelContext) -> SSHFolderImportResult {
        let panel = NSOpenPanel()
        panel.title = "Import SSH keys and connections"
        panel.message = "Select your .ssh folder to import keys and ~/.ssh/config entries into mSSH. Keys sync to iCloud so they'll appear on your iPhone and iPad automatically."
        panel.prompt = "Import"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".ssh")
        panel.showsHiddenFiles = true

        UserDefaults.standard.set(true, forKey: didPromptKey)

        guard panel.runModal() == .OK, let url = panel.url else {
            return SSHFolderImportResult()
        }

        // Persist a security-scoped bookmark so subsequent launches can
        // re-access the folder without prompting again.
        if let data = try? url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) {
            UserDefaults.standard.set(data, forKey: bookmarkKey)
        }

        return importFolder(at: url, modelContext: modelContext, alreadyAuthorised: false)
    }

    /// Run an import silently using the stored bookmark. Returns nil if the
    /// user has never granted folder access, or if the bookmark can't be
    /// resolved (user relocated / deleted the folder).
    @discardableResult
    static func runWithStoredBookmark(modelContext: ModelContext) -> SSHFolderImportResult? {
        guard let data = UserDefaults.standard.data(forKey: bookmarkKey) else { return nil }

        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: data,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else {
            UserDefaults.standard.removeObject(forKey: bookmarkKey)
            return nil
        }

        return importFolder(at: url, modelContext: modelContext, alreadyAuthorised: false)
    }

    /// True if the user hasn't been asked yet — callers (msshApp) use this
    /// to decide whether to auto-prompt on first launch.
    static var shouldAutoPrompt: Bool {
        UserDefaults.standard.data(forKey: bookmarkKey) == nil
            && !UserDefaults.standard.bool(forKey: didPromptKey)
    }

    // MARK: - Core import

    private static func importFolder(
        at folderURL: URL,
        modelContext: ModelContext,
        alreadyAuthorised: Bool
    ) -> SSHFolderImportResult {
        var result = SSHFolderImportResult()
        let fm = FileManager.default

        // Security-scoped access — required for bookmarked URLs under the sandbox.
        let didStart = folderURL.startAccessingSecurityScopedResource()
        defer { if didStart { folderURL.stopAccessingSecurityScopedResource() } }

        guard let entries = try? fm.contentsOfDirectory(
            at: folderURL,
            includingPropertiesForKeys: [.isRegularFileKey]
        ) else {
            result.errors.append("Could not read folder contents at \(folderURL.path)")
            return result
        }

        let existingKeys = (try? modelContext.fetch(FetchDescriptor<SSHKey>())) ?? []
        let existingLabels = Set(existingKeys.map { $0.label })

        for entry in entries {
            guard
                let values = try? entry.resourceValues(forKeys: [.isRegularFileKey]),
                values.isRegularFile == true
            else { continue }

            let name = entry.lastPathComponent
            // Skip obvious non-private-key files.
            if name.hasSuffix(".pub") { continue }
            if ["known_hosts", "known_hosts.old", "config", "authorized_keys", ".DS_Store", "environment"].contains(name) {
                continue
            }

            guard let data = try? Data(contentsOf: entry),
                  let text = String(data: data, encoding: .utf8) else {
                continue
            }

            // Must look like a PEM private key.
            guard text.contains("PRIVATE KEY") else { continue }

            // Encrypted keys aren't supported by Citadel's readers.
            if text.contains("ENCRYPTED") || text.contains("Proc-Type: 4,ENCRYPTED") {
                result.errors.append("\(name): encrypted (remove passphrase with `ssh-keygen -p -f \(name)`)")
                continue
            }

            let label = entry.deletingPathExtension().lastPathComponent
            if existingLabels.contains(label) {
                result.keysSkipped += 1
                continue
            }

            do {
                _ = try KeyManagementService.importKey(
                    label: label,
                    pemText: text,
                    modelContext: modelContext,
                    syncAcrossDevices: true
                )
                result.keysImported += 1
            } catch {
                result.errors.append("\(name): \(error.localizedDescription)")
            }
        }

        // `~/.ssh/config` parsing — reuse the existing SSHConfigParser.
        let configURL = folderURL.appendingPathComponent("config")
        if fm.fileExists(atPath: configURL.path),
           let configText = try? String(contentsOf: configURL, encoding: .utf8) {
            let parsed = SSHConfigParser.parse(configText)
            let existingProfiles = (try? modelContext.fetch(FetchDescriptor<ConnectionProfile>())) ?? []
            for entry in parsed where entry.hostAlias != "*" {
                // Skip entries that don't resolve to a concrete host.
                let host = entry.effectiveHost
                let user = entry.effectiveUser
                let port = entry.effectivePort
                guard !host.isEmpty, host != "*" else { continue }

                let dup = existingProfiles.contains { existing in
                    existing.host == host && existing.username == user && existing.port == port
                }
                if dup {
                    result.profilesSkipped += 1
                    continue
                }
                let profile = ConnectionProfile(
                    label: entry.displayLabel,
                    host: host,
                    port: port,
                    username: user,
                    authType: entry.identityFile != nil ? .key : .password
                )
                modelContext.insert(profile)
                result.profilesImported += 1
            }
        }

        try? modelContext.save()
        return result
    }
}
#endif
