import Foundation
import SwiftData
import SwiftUI
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
        isFavorite: Bool = false,
        groupName: String? = nil,
        colorTag: String? = nil,
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
            target.isFavorite = isFavorite
            target.groupName = groupName
            target.colorTag = colorTag
        } else {
            target = ConnectionProfile(
                label: label,
                host: host,
                port: port,
                username: username,
                authType: authType,
                keyID: keyID,
                isFavorite: isFavorite,
                groupName: groupName,
                colorTag: colorTag
            )
            modelContext.insert(target)
        }

        // Save to SwiftData first so the model is persisted
        try? modelContext.save()

        // Save password to both device-only and iCloud Keychain
        if authType == .password, let password, !password.isEmpty {
            // Device-only (backwards compatible, always works)
            try? KeychainService.savePassword(
                for: target.syncID,
                password: password
            )
            // iCloud Keychain (syncs across devices)
            try? KeychainService.savePasswordSyncable(
                for: target.syncID,
                password: password
            )
        }
    }
}

// MARK: - Connection grouping & filtering helpers

/// Pure-data helpers for slicing the connection list. Live outside the
/// `@Observable` class so they're trivially testable and can be reused by
/// both the iPhone and iPad list views without duplicating logic.
enum ConnectionListSorter {
    /// Filter by label/host/username/groupName, case-insensitive contains.
    /// An empty query returns everything.
    static func filter(_ connections: [ConnectionProfile], query: String) -> [ConnectionProfile] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return connections }
        let needle = trimmed.lowercased()
        return connections.filter { profile in
            profile.label.lowercased().contains(needle)
                || profile.host.lowercased().contains(needle)
                || profile.username.lowercased().contains(needle)
                || (profile.groupName?.lowercased().contains(needle) ?? false)
        }
    }

    /// Default sort: most-recently-connected first, then alphabetical.
    static func recencySorted(_ connections: [ConnectionProfile]) -> [ConnectionProfile] {
        connections.sorted { lhs, rhs in
            let l = lhs.lastConnectedAt ?? .distantPast
            let r = rhs.lastConnectedAt ?? .distantPast
            if l != r { return l > r }
            return lhs.label.localizedCaseInsensitiveCompare(rhs.label) == .orderedAscending
        }
    }

    /// Split a connection list into ordered sections for the UI:
    ///   1. "Favorites" — every isFavorite==true profile, recency-sorted
    ///   2. One section per non-nil groupName (alphabetical group order),
    ///      excluding favorites
    ///   3. "Other" — the catch-all for groupName==nil, excluding favorites
    /// Sections that would be empty are omitted.
    static func sections(_ connections: [ConnectionProfile]) -> [ConnectionSection] {
        var sections: [ConnectionSection] = []

        let favorites = recencySorted(connections.filter { $0.isFavorite })
        if !favorites.isEmpty {
            sections.append(ConnectionSection(id: "__favorites__", title: "Favorites", isFavorites: true, items: favorites))
        }

        let nonFavorites = connections.filter { !$0.isFavorite }
        // Treat blank "" group names as nil so an empty-string group doesn't
        // create a phantom section titled "" alongside the real groups.
        let grouped = Dictionary(grouping: nonFavorites) { profile -> String? in
            guard let name = profile.groupName, !name.isEmpty else { return nil }
            return name
        }

        // Sorted group names (nil goes last as "Other")
        let namedGroups = grouped.keys
            .compactMap { $0 }
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }

        for name in namedGroups {
            let items = recencySorted(grouped[name] ?? [])
            if !items.isEmpty {
                sections.append(ConnectionSection(id: "group:\(name)", title: name, isFavorites: false, items: items))
            }
        }

        if let ungrouped = grouped[nil], !ungrouped.isEmpty {
            // Only label this section "Other" when there are also named groups;
            // otherwise it's the only section and "Connections" is clearer.
            let title = namedGroups.isEmpty ? "Connections" : "Other"
            sections.append(ConnectionSection(id: "__ungrouped__", title: title, isFavorites: false, items: recencySorted(ungrouped)))
        }

        return sections
    }

    /// Distinct existing group names — used to power the autocomplete
    /// menu in the connection form.
    static func existingGroupNames(_ connections: [ConnectionProfile]) -> [String] {
        let names = connections.compactMap { $0.groupName }.filter { !$0.isEmpty }
        let unique = Set(names)
        return unique.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }
}

struct ConnectionSection: Identifiable {
    let id: String
    let title: String
    let isFavorites: Bool
    let items: [ConnectionProfile]
}

// MARK: - Color tag rendering

extension ConnectionProfile {
    /// Map a `tagPalette` name to a SwiftUI Color. Returns nil for nil input
    /// or unrecognised names so callers can decide their own fallback.
    static func tagColor(named name: String?) -> Color? {
        switch name?.lowercased() {
        case "red": return .red
        case "orange": return .orange
        case "yellow": return .yellow
        case "green": return .green
        case "teal": return .teal
        case "blue": return .blue
        case "indigo": return .indigo
        case "purple": return .purple
        case "pink": return .pink
        default: return nil
        }
    }

    /// Resolve this profile's `colorTag` to a SwiftUI Color via `tagColor(named:)`.
    var resolvedTagColor: Color? { ConnectionProfile.tagColor(named: colorTag) }
}
