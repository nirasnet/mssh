import SwiftUI
import SwiftData
import UniformTypeIdentifiers

// MARK: - Import Selection State

private struct ConfigHostSelection: Identifiable {
    let id = UUID()
    let entry: SSHConfigEntry
    var selected: Bool
    var label: String
}

// MARK: - Main View

struct SSHConfigImportView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var existingKeys: [SSHKey]

    @State private var showFilePicker = false
    @State private var configText = ""
    @State private var parsedEntries: [SSHConfigEntry] = []
    @State private var selections: [ConfigHostSelection] = []
    @State private var hasParsed = false
    @State private var importedCount = 0
    @State private var showResult = false
    @State private var errorMessage: String?
    @State private var showPasteOption = false

    var body: some View {
        NavigationStack {
            Group {
                if !hasParsed {
                    sourceView
                } else {
                    previewView
                }
            }
            .navigationTitle("Import SSH Config")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if hasParsed {
                        Button("Import") {
                            performImport()
                        }
                        .bold()
                        .disabled(selections.filter(\.selected).isEmpty)
                    }
                }
            }
            .fileImporter(
                isPresented: $showFilePicker,
                allowedContentTypes: [.plainText, .data, .item],
                allowsMultipleSelection: false
            ) { result in
                handleFilePickerResult(result)
            }
            .alert("Import Complete", isPresented: $showResult) {
                Button("Done") { dismiss() }
            } message: {
                Text("Created \(importedCount) connection profile(s).")
            }
            .alert("Error", isPresented: .init(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
            .sheet(isPresented: $showPasteOption) {
                pasteConfigSheet
            }
        }
    }

    // MARK: - Source Selection

    private var sourceView: some View {
        List {
            Section {
                Button {
                    showFilePicker = true
                } label: {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Browse for Config File")
                                .font(.headline)
                                .foregroundStyle(.primary)
                            Text("Select your ~/.ssh/config file from iCloud Drive or Files")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "folder")
                            .font(.title2)
                            .foregroundStyle(Color.accentColor)
                    }
                    .padding(.vertical, 4)
                }

                Button {
                    showPasteOption = true
                } label: {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Paste Config Text")
                                .font(.headline)
                                .foregroundStyle(.primary)
                            Text("Paste the contents of your SSH config file")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "doc.on.clipboard")
                            .font(.title2)
                            .foregroundStyle(Color.accentColor)
                    }
                    .padding(.vertical, 4)
                }
            } header: {
                Text("Select SSH Config")
            } footer: {
                Text("Your SSH config file is typically located at ~/.ssh/config on your Mac. Copy it to iCloud Drive or paste its contents to import your saved connections.")
            }

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Label("What gets imported?", systemImage: "info.circle")
                        .font(.subheadline.bold())

                    VStack(alignment: .leading, spacing: 4) {
                        BulletPoint("Host aliases and hostnames")
                        BulletPoint("Usernames and port numbers")
                        BulletPoint("IdentityFile references (mapped to imported keys)")
                        BulletPoint("Wildcard (*) entries are used as defaults")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
    }

    // MARK: - Paste Config Sheet

    private var pasteConfigSheet: some View {
        NavigationStack {
            Form {
                Section("SSH Config") {
                    TextEditor(text: $configText)
                        .font(.system(.caption, design: .monospaced))
                        .frame(minHeight: 250)
                }

                Section {
                    Text("Paste the full contents of your ~/.ssh/config file.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Paste Config")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showPasteOption = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Parse") {
                        showPasteOption = false
                        parseConfig(configText)
                    }
                    .disabled(configText.isEmpty)
                }
            }
        }
        .presentationDetents([.large])
    }

    // MARK: - Preview

    private var previewView: some View {
        List {
            if selections.isEmpty {
                ContentUnavailableView(
                    "No Hosts Found",
                    systemImage: "network.slash",
                    description: Text("No concrete host entries were found in the config file. Wildcard-only configs cannot be imported as connection profiles.")
                )
            } else {
                Section {
                    ForEach($selections) { $selection in
                        Toggle(isOn: $selection.selected) {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(selection.entry.hostAlias)
                                        .font(.headline)
                                    Spacer()
                                    if let identityFile = selection.entry.identityFile {
                                        let mapped = matchKeyForIdentityFile(identityFile)
                                        if mapped != nil {
                                            Image(systemName: "key.fill")
                                                .font(.caption)
                                                .foregroundStyle(.green)
                                        } else {
                                            Image(systemName: "key")
                                                .font(.caption)
                                                .foregroundStyle(.orange)
                                        }
                                    }
                                }

                                HStack(spacing: 12) {
                                    Label(selection.entry.effectiveHost, systemImage: "server.rack")
                                    Label("\(selection.entry.effectiveUser)@:\(selection.entry.effectivePort)",
                                          systemImage: "person")
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)

                                if let identityFile = selection.entry.identityFile {
                                    let mapped = matchKeyForIdentityFile(identityFile)
                                    HStack(spacing: 4) {
                                        Image(systemName: mapped != nil ? "checkmark.circle" : "exclamationmark.triangle")
                                        if let key = mapped {
                                            Text("Key: \(key.label)")
                                        } else {
                                            Text("Key not imported: \(identityFile)")
                                        }
                                    }
                                    .font(.caption2)
                                    .foregroundStyle(mapped != nil ? .green : .orange)
                                }
                            }
                        }
                        .toggleStyle(.switch)
                        .padding(.vertical, 2)
                    }
                } header: {
                    Text("Connections (\(selections.count) found)")
                } footer: {
                    let selectedCount = selections.filter(\.selected).count
                    Text("\(selectedCount) connection(s) will be created as new profiles.")
                }

                if !parsedEntries.filter({ $0.hostAlias == "*" }).isEmpty {
                    Section("Global Defaults Applied") {
                        let globals = parsedEntries.filter { $0.hostAlias == "*" }
                        ForEach(globals) { global in
                            VStack(alignment: .leading, spacing: 4) {
                                if let user = global.user {
                                    LabeledContent("Default User", value: user)
                                }
                                if let port = global.port {
                                    LabeledContent("Default Port", value: "\(port)")
                                }
                                if let id = global.identityFile {
                                    LabeledContent("Default IdentityFile", value: id)
                                }
                            }
                            .font(.caption)
                        }
                    }
                }

                Section {
                    Button {
                        hasParsed = false
                        configText = ""
                        selections = []
                        parsedEntries = []
                    } label: {
                        Label("Choose Different File", systemImage: "arrow.uturn.backward")
                    }
                }
            }
        }
    }

    // MARK: - Actions

    private func handleFilePickerResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            guard url.startAccessingSecurityScopedResource() else {
                errorMessage = "Could not access the selected file."
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }

            guard let data = try? Data(contentsOf: url),
                  let text = String(data: data, encoding: .utf8) else {
                errorMessage = "Could not read the selected file."
                return
            }
            parseConfig(text)

        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }

    private func parseConfig(_ text: String) {
        parsedEntries = SSHConfigParser.parse(text)
        let concreteHosts = SSHConfigParser.concreteHosts(from: parsedEntries)

        selections = concreteHosts.map { entry in
            let resolved = SSHConfigParser.resolve(entry, withDefaults: parsedEntries)
            return ConfigHostSelection(
                entry: resolved,
                selected: true,
                label: entry.hostAlias
            )
        }
        hasParsed = true
    }

    private func matchKeyForIdentityFile(_ path: String) -> SSHKey? {
        // Try to match by filename (e.g. ~/.ssh/id_ed25519 -> label contains "id_ed25519")
        let filename = (path as NSString).lastPathComponent
        return existingKeys.first { key in
            key.label.lowercased().contains(filename.lowercased()) ||
            filename.lowercased().contains(key.label.lowercased())
        }
    }

    private func performImport() {
        let selected = selections.filter(\.selected)
        importedCount = 0

        for selection in selected {
            let entry = selection.entry
            let matchedKey = entry.identityFile.flatMap { matchKeyForIdentityFile($0) }

            let profile = ConnectionProfile(
                label: selection.label,
                host: entry.effectiveHost,
                port: entry.effectivePort,
                username: entry.effectiveUser,
                authType: matchedKey != nil ? .key : .password,
                keyID: matchedKey?.keychainID
            )
            modelContext.insert(profile)
            importedCount += 1
        }

        showResult = true
    }
}

// MARK: - Bullet Point Helper

private struct BulletPoint: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Text("\u{2022}")
            Text(text)
        }
    }
}
