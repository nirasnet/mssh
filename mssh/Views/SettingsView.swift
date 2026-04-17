import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(iCloudSyncService.self) private var syncService
    @State private var showClearDataAlert = false
    @State private var showRestartAlert = false
    @State private var importSummary: String?
    @State private var showImportResult = false

    @AppStorage(AppPreferences.Key.terminalThemeName)
    private var themeName = AppPreferences.Default.terminalThemeName
    @AppStorage(AppPreferences.Key.terminalFontFamily)
    private var fontFamily = AppPreferences.Default.terminalFontFamily
    @AppStorage(AppPreferences.Key.terminalFontSize)
    private var fontSize = AppPreferences.Default.terminalFontSize
    @AppStorage(AppPreferences.Key.terminalCursorStyle)
    private var cursorStyleRaw = AppPreferences.Default.terminalCursorStyle
    @AppStorage(AppPreferences.Key.terminalBlinkCursor)
    private var blinkCursor = AppPreferences.Default.terminalBlinkCursor

    @AppStorage("biometricEnabled") private var biometricEnabled = false
    @AppStorage("lockOnBackground") private var lockOnBackground = true
    @AppStorage("cloudSyncEnabled") private var cloudSyncEnabled = true

    private var biometricsAvailable: Bool {
        BiometricService.canUseBiometrics()
    }

    private var biometricLabel: String {
        switch BiometricService.biometricType() {
        case .faceID: return "Require Face ID"
        case .touchID: return "Require Touch ID"
        case .none: return "Require Biometrics"
        }
    }

    private var biometricIcon: String {
        switch BiometricService.biometricType() {
        case .faceID: return "faceid"
        case .touchID: return "touchid"
        case .none: return "lock.shield"
        }
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }

    private var appBuild: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
    }

    private var syncStatusColor: Color {
        switch syncService.status {
        case .synced:       return AppColors.connected
        case .syncing:      return AppColors.accent
        case .notStarted:   return AppColors.textSecondary
        case .notAvailable: return AppColors.warning
        case .error:        return AppColors.error
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                // Appearance
                Section {
                    ForEach(TerminalTheme.allThemes, id: \.name) { theme in
                        Button {
                            themeName = theme.name
                        } label: {
                            HStack(spacing: AppSpacing.md) {
                                ThemeSwatch(theme: theme)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(theme.name)
                                        .font(.subheadline)
                                        .foregroundStyle(AppColors.textPrimary)
                                    Text("$ ssh root@host")
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundStyle(theme.foreground.opacity(0.85))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(theme.background)
                                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                                }
                                Spacer()
                                if themeName == theme.name {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(AppColors.accent)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Label("Appearance", systemImage: "paintpalette")
                } footer: {
                    Text("Theme applies on the next terminal repaint or new session.")
                }

                // Terminal
                Section {
                    Picker(selection: $fontFamily) {
                        ForEach(AppPreferences.availableFontFamilies, id: \.self) { name in
                            Text(name).tag(name)
                        }
                    } label: {
                        Label("Font Family", systemImage: "textformat")
                    }

                    HStack {
                        Label("Font Size", systemImage: "textformat.size")
                        Spacer()
                        Stepper(value: $fontSize, in: AppPreferences.fontSizeRange) {
                            Text("\(fontSize) pt")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(AppColors.accent)
                                .frame(minWidth: 44, alignment: .trailing)
                        }
                    }

                    Picker(selection: $cursorStyleRaw) {
                        ForEach(AppPreferences.CursorStyle.allCases) { style in
                            Text(style.displayName).tag(style.rawValue)
                        }
                    } label: {
                        Label("Cursor", systemImage: "cursorarrow.click")
                    }

                    Toggle(isOn: $blinkCursor) {
                        Label("Blink Cursor", systemImage: "cursorarrow.click.badge.clock")
                    }
                    .tint(AppColors.accent)

                    // Live preview
                    HStack {
                        Text("Preview")
                            .foregroundStyle(AppColors.textSecondary)
                        Spacer()
                        Text("ssh root@host")
                            .font(previewFont())
                            .foregroundStyle(TerminalTheme.named(themeName).foreground)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(TerminalTheme.named(themeName).background)
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                } header: {
                    Label("Terminal", systemImage: "terminal")
                }

                // Security
                Section {
                    Toggle(isOn: $biometricEnabled) {
                        Label(biometricLabel, systemImage: biometricIcon)
                    }
                    .disabled(!biometricsAvailable)
                    .tint(AppColors.accent)

                    if biometricEnabled {
                        Toggle(isOn: $lockOnBackground) {
                            Label("Lock on Background", systemImage: "rectangle.portrait.and.arrow.forward")
                        }
                        .tint(AppColors.accent)
                    }
                } header: {
                    Label("Security", systemImage: "lock.shield")
                } footer: {
                    if !biometricsAvailable {
                        Text("Biometric authentication is not available on this device.")
                    } else if biometricEnabled {
                        Text("Authentication required when opening the app\(lockOnBackground ? " and returning from background" : "").")
                    }
                }

                // Sync — live status from iCloudSyncService
                Section {
                    Toggle(isOn: $cloudSyncEnabled) {
                        Label("iCloud Sync", systemImage: "icloud")
                    }
                    .onChange(of: cloudSyncEnabled) {
                        showRestartAlert = true
                    }

                    if cloudSyncEnabled {
                        HStack {
                            Label("Status", systemImage: syncService.status.systemImage)
                            Spacer()
                            Text(syncService.status.label)
                                .font(.caption)
                                .foregroundStyle(syncStatusColor)
                        }
                        if let date = syncService.lastSyncDate {
                            HStack {
                                Label("Last Sync", systemImage: "clock.arrow.circlepath")
                                Spacer()
                                Text(date, style: .relative)
                                    .font(.caption)
                                    .foregroundStyle(AppColors.textSecondary)
                            }
                        }
                        HStack {
                            Label("iCloud Account", systemImage: "person.icloud")
                            Spacer()
                            if FileManager.default.ubiquityIdentityToken != nil {
                                Text("Signed in")
                                    .font(.caption)
                                    .foregroundStyle(AppColors.connected)
                            } else {
                                Text("Not signed in")
                                    .font(.caption)
                                    .foregroundStyle(AppColors.warning)
                            }
                        }
                        HStack {
                            Label("Keychain Sync", systemImage: "key.icloud")
                            Spacer()
                            Text("Passwords · opt-in keys")
                                .font(.caption)
                                .foregroundStyle(AppColors.textSecondary)
                        }
                        // Push/Pull via NSUbiquitousKeyValueStore — works
                        // on all platforms without CloudKit.
                        Button {
                            let result = ConnectionSyncBridge.push(modelContext: modelContext)
                            importSummary = "Pushed \(result.connections) connection\(result.connections == 1 ? "" : "s") + \(result.snippets) snippet\(result.snippets == 1 ? "" : "s") to iCloud."
                            showImportResult = true
                        } label: {
                            Label("Push to iCloud", systemImage: "icloud.and.arrow.up")
                                .foregroundStyle(AppColors.accent)
                        }

                        Button {
                            let result = ConnectionSyncBridge.pull(modelContext: modelContext)
                            importSummary = "Pulled \(result.connections) new connection\(result.connections == 1 ? "" : "s") + \(result.snippets) new snippet\(result.snippets == 1 ? "" : "s") from iCloud."
                            showImportResult = true
                        } label: {
                            Label("Pull from iCloud", systemImage: "icloud.and.arrow.down")
                                .foregroundStyle(AppColors.accent)
                        }

                        #if os(macOS)
                        Button {
                            let result = SSHFolderImporter.promptAndImport(modelContext: modelContext)
                            importSummary = result.humanSummary +
                                (result.errors.isEmpty ? "" : "\n\n" + result.errors.joined(separator: "\n"))
                            showImportResult = true
                        } label: {
                            Label("Import from ~/.ssh Folder", systemImage: "square.and.arrow.down.on.square")
                                .foregroundStyle(AppColors.accent)
                        }
                        #endif
                    }
                } header: {
                    Label("Sync", systemImage: "arrow.triangle.2.circlepath")
                } footer: {
                    if cloudSyncEnabled {
                        Text("Connections, SSH key metadata, known hosts, snippets, and port forwards sync via iCloud. Passwords sync via iCloud Keychain. Private SSH key material is device-only unless you flip \"Sync across devices\" on a specific key in the Keys tab.")
                    } else {
                        Text("All data is stored locally on this device only. Turn on to sync across iPhone, iPad, and Mac.")
                    }
                }
                .alert("Restart Required", isPresented: $showRestartAlert) {
                    Button("OK") {}
                } message: {
                    Text("Please quit and reopen mSSH for the sync change to take effect.")
                }

                // SSH (Known Hosts, Snippets)
                Section {
                    NavigationLink {
                        KnownHostsView()
                    } label: {
                        Label("Known Hosts", systemImage: "server.rack")
                    }
                    NavigationLink {
                        SnippetsView()
                    } label: {
                        Label("Snippets", systemImage: "text.badge.plus")
                    }
                } header: {
                    Label("SSH", systemImage: "network")
                }

                // Data Management
                Section {
                    Button(role: .destructive) {
                        showClearDataAlert = true
                    } label: {
                        Label("Clear All Data", systemImage: "trash")
                            .foregroundStyle(.red)
                    }
                } header: {
                    Label("Data", systemImage: "externaldrive")
                } footer: {
                    Text("Removes all connections, keys, snippets, port forwards, and known hosts from this device.")
                }
                .alert("Clear All Data?", isPresented: $showClearDataAlert) {
                    Button("Cancel", role: .cancel) {}
                    Button("Clear Everything", role: .destructive) {
                        clearAllData()
                    }
                } message: {
                    Text("This will delete all connections, SSH keys, snippets, port forwards, and known hosts. This cannot be undone.")
                }

                // About
                Section {
                    HStack {
                        Label("Version", systemImage: "info.circle")
                        Spacer()
                        Text(appVersion)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(AppColors.textSecondary)
                    }
                    HStack {
                        Label("Build", systemImage: "hammer")
                        Spacer()
                        Text(appBuild)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(AppColors.textSecondary)
                    }
                    HStack {
                        Label("SSH Engine", systemImage: "shippingbox")
                        Spacer()
                        Text("Citadel")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(AppColors.textSecondary)
                    }
                    HStack {
                        Label("Terminal Engine", systemImage: "shippingbox")
                        Spacer()
                        Text("SwiftTerm")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(AppColors.textSecondary)
                    }
                    HStack {
                        Label("Source", systemImage: "chevron.left.forwardslash.chevron.right")
                        Spacer()
                        Text("github.com/m4ck/mssh")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(AppColors.textSecondary)
                    }
                } header: {
                    Label("About", systemImage: "info.circle")
                } footer: {
                    Text("Built with Citadel (orlandos-nl) and SwiftTerm (migueldeicaza).")
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppColors.background)
            .navigationTitle("Settings")
            .iOSOnlyNavigationBarTitleDisplayMode()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
            .alert("Import Complete", isPresented: $showImportResult) {
                Button("OK") {}
            } message: {
                Text(importSummary ?? "")
            }
        }
        .appTheme()
    }

    /// Resolved preview font that honors family + size, with a system fallback.
    private func previewFont() -> Font {
        let pt = CGFloat(fontSize)
        if fontFamily == "System" {
            return .system(size: pt, design: .monospaced)
        }
        return .custom(fontFamily, size: pt)
    }

    private func clearAllData() {
        let context = modelContext
        do {
            try context.delete(model: ConnectionProfile.self)
            try context.delete(model: SSHKey.self)
            try context.delete(model: KnownHost.self)
            try context.delete(model: Snippet.self)
            try context.delete(model: PortForward.self)
            try context.save()
        } catch {
            print("[mSSH] Failed to clear data: \(error)")
        }
    }
}

// MARK: - Theme swatch for the appearance picker

private struct ThemeSwatch: View {
    let theme: TerminalTheme

    var body: some View {
        HStack(spacing: 0) {
            theme.background
            theme.foreground
            theme.cursorColor
        }
        .frame(width: 36, height: 24)
        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .strokeBorder(Color.white.opacity(0.15), lineWidth: 0.5)
        )
    }
}
