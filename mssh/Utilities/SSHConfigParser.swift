import Foundation

/// Represents a single Host block parsed from an OpenSSH config file.
struct SSHConfigEntry: Identifiable {
    let id = UUID()
    var hostAlias: String
    var hostName: String?
    var user: String?
    var port: Int?
    var identityFile: String?
    var proxyJump: String?
    var forwardAgent: Bool?
    var extraOptions: [String: String] = [:]

    /// Human-readable display label derived from the host alias.
    var displayLabel: String {
        if hostAlias == "*" { return "Global Defaults" }
        return hostAlias
    }

    /// The effective hostname, falling back to the alias if HostName is not set.
    var effectiveHost: String {
        hostName ?? hostAlias
    }

    /// The effective port, defaulting to 22.
    var effectivePort: Int {
        port ?? 22
    }

    /// The effective user, defaulting to "root".
    var effectiveUser: String {
        user ?? "root"
    }
}

/// Parses OpenSSH-format config files into structured entries.
enum SSHConfigParser {

    // MARK: - Public API

    /// Parse the full text of an SSH config file.
    /// Returns an array of `SSHConfigEntry`, one per Host or Match block.
    static func parse(_ configText: String) -> [SSHConfigEntry] {
        let lines = configText.components(separatedBy: .newlines)
        var entries: [SSHConfigEntry] = []
        var currentEntry: SSHConfigEntry?

        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: .whitespaces)

            // Skip empty lines and comments
            if line.isEmpty || line.hasPrefix("#") {
                continue
            }

            // Strip inline comments (but not inside quoted strings)
            let effectiveLine = stripInlineComment(line)

            // Detect Host or Match block starts
            if let hostValue = extractDirective("Host", from: effectiveLine) {
                // Save any previous entry
                if let entry = currentEntry {
                    entries.append(entry)
                }
                // A Host line can list multiple patterns separated by spaces.
                // We create one entry per pattern for simplicity.
                let patterns = hostValue.components(separatedBy: .whitespaces)
                    .filter { !$0.isEmpty }
                if let first = patterns.first {
                    currentEntry = SSHConfigEntry(hostAlias: first)
                } else {
                    currentEntry = SSHConfigEntry(hostAlias: hostValue)
                }
                continue
            }

            if let matchValue = extractDirective("Match", from: effectiveLine) {
                if let entry = currentEntry {
                    entries.append(entry)
                }
                currentEntry = SSHConfigEntry(hostAlias: "Match \(matchValue)")
                continue
            }

            // Parse key-value directives within a block
            guard currentEntry != nil else { continue }
            applyDirective(effectiveLine, to: &currentEntry!)
        }

        // Don't forget the last entry
        if let entry = currentEntry {
            entries.append(entry)
        }

        return entries
    }

    /// Filter parsed entries to only those that represent concrete hosts
    /// (not wildcards, not Match blocks).
    static func concreteHosts(from entries: [SSHConfigEntry]) -> [SSHConfigEntry] {
        entries.filter { entry in
            !entry.hostAlias.contains("*") &&
            !entry.hostAlias.contains("?") &&
            !entry.hostAlias.hasPrefix("Match ")
        }
    }

    /// Resolve a concrete host entry by merging global defaults (Host *).
    static func resolve(_ entry: SSHConfigEntry, withDefaults entries: [SSHConfigEntry]) -> SSHConfigEntry {
        // Find wildcard/global entries
        let globals = entries.filter { $0.hostAlias == "*" }
        var resolved = entry

        for global in globals {
            if resolved.hostName == nil { resolved.hostName = global.hostName }
            if resolved.user == nil { resolved.user = global.user }
            if resolved.port == nil { resolved.port = global.port }
            if resolved.identityFile == nil { resolved.identityFile = global.identityFile }
            if resolved.proxyJump == nil { resolved.proxyJump = global.proxyJump }
            if resolved.forwardAgent == nil { resolved.forwardAgent = global.forwardAgent }
            for (key, value) in global.extraOptions where resolved.extraOptions[key] == nil {
                resolved.extraOptions[key] = value
            }
        }

        return resolved
    }

    // MARK: - Private Helpers

    /// Extract the value for a named directive if the line starts with it.
    private static func extractDirective(_ name: String, from line: String) -> String? {
        // Support both "Keyword value" and "Keyword=value"
        let lower = line.lowercased()
        let nameLower = name.lowercased()

        if lower.hasPrefix(nameLower) {
            let rest = line.dropFirst(name.count)
            if let first = rest.first {
                if first == "=" {
                    let value = String(rest.dropFirst()).trimmingCharacters(in: .whitespaces)
                    return value.isEmpty ? nil : stripQuotes(value)
                } else if first == " " || first == "\t" {
                    let value = String(rest).trimmingCharacters(in: .whitespaces)
                    return value.isEmpty ? nil : stripQuotes(value)
                }
            }
        }
        return nil
    }

    /// Apply a directive line to the current entry being built.
    private static func applyDirective(_ line: String, to entry: inout SSHConfigEntry) {
        if let value = extractDirective("HostName", from: line) {
            entry.hostName = value
        } else if let value = extractDirective("User", from: line) {
            entry.user = value
        } else if let value = extractDirective("Port", from: line) {
            entry.port = Int(value)
        } else if let value = extractDirective("IdentityFile", from: line) {
            entry.identityFile = value
        } else if let value = extractDirective("ProxyJump", from: line) {
            entry.proxyJump = value
        } else if let value = extractDirective("ForwardAgent", from: line) {
            entry.forwardAgent = value.lowercased() == "yes"
        } else {
            // Store any other directives as extras
            let parts = splitDirective(line)
            if let key = parts.key {
                entry.extraOptions[key] = parts.value
            }
        }
    }

    /// Split a directive line into key and value.
    private static func splitDirective(_ line: String) -> (key: String?, value: String) {
        // Handle "Key=Value"
        if let eqIndex = line.firstIndex(of: "=") {
            let key = String(line[line.startIndex..<eqIndex]).trimmingCharacters(in: .whitespaces)
            let value = String(line[line.index(after: eqIndex)...]).trimmingCharacters(in: .whitespaces)
            return (key.isEmpty ? nil : key, stripQuotes(value))
        }
        // Handle "Key Value"
        let parts = line.split(separator: " ", maxSplits: 1)
        if parts.count == 2 {
            return (String(parts[0]), stripQuotes(String(parts[1]).trimmingCharacters(in: .whitespaces)))
        }
        return (nil, line)
    }

    /// Remove surrounding double quotes from a value.
    private static func stripQuotes(_ value: String) -> String {
        if value.hasPrefix("\"") && value.hasSuffix("\"") && value.count >= 2 {
            return String(value.dropFirst().dropLast())
        }
        return value
    }

    /// Strip an inline comment (text after an unquoted #).
    private static func stripInlineComment(_ line: String) -> String {
        var inQuote = false
        for (index, char) in line.enumerated() {
            if char == "\"" {
                inQuote.toggle()
            } else if char == "#" && !inQuote {
                let prefix = line.prefix(index).trimmingCharacters(in: .whitespaces)
                return prefix
            }
        }
        return line
    }
}
