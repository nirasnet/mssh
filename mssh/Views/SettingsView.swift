import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var showClearDataAlert = false
    @AppStorage("terminalThemeName") private var themeName = "Default"
    @AppStorage("terminalFontSize") private var fontSize = 13.0
    @AppStorage("biometricEnabled") private var biometricEnabled = false
    @AppStorage("lockOnBackground") private var lockOnBackground = true
    @AppStorage("cloudSyncEnabled") private var cloudSyncEnabled = true
    @State private var showRestartAlert = false

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

    var body: some View {
        NavigationStack {
            Form {
                // Terminal
                Section {
                    Picker("Theme", selection: $themeName) {
                        ForEach(TerminalTheme.allThemes, id: \.name) { theme in
                            HStack {
                                Circle()
                                    .fill(theme.background)
                                    .frame(width: 16, height: 16)
                                    .overlay(
                                        Circle()
                                            .strokeBorder(Color.white.opacity(0.2), lineWidth: 0.5)
                                    )
                                Text(theme.name)
                            }
                            .tag(theme.name)
                        }
                    }

                    VStack(spacing: AppSpacing.sm) {
                        HStack {
                            Text("Font Size")
                            Spacer()
                            Text("\(Int(fontSize))pt")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(AppColors.accent)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(AppColors.accentDim)
                                .clipShape(Capsule())
                        }
                        Slider(value: $fontSize, in: 8...24, step: 1)
                            .tint(AppColors.accent)
                    }

                    // Font preview
                    HStack {
                        Text("Preview")
                            .foregroundStyle(AppColors.textSecondary)
                        Spacer()
                        Text("ssh root@host")
                            .font(.system(size: CGFloat(fontSize), design: .monospaced))
                            .foregroundStyle(AppColors.accent)
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

                // SSH
                Section {
                    NavigationLink {
                        KnownHostsView()
                    } label: {
                        Label("Known Hosts", systemImage: "server.rack")
                    }
                } header: {
                    Label("SSH", systemImage: "network")
                }

                // Sync
                Section {
                    Toggle(isOn: $cloudSyncEnabled) {
                        Label("iCloud Sync", systemImage: "icloud")
                    }
                    .onChange(of: cloudSyncEnabled) {
                        showRestartAlert = true
                    }

                    if cloudSyncEnabled {
                        HStack {
                            Label("Status", systemImage: "arrow.triangle.2.circlepath")
                            Spacer()
                            if FileManager.default.ubiquityIdentityToken != nil {
                                Text("Active")
                                    .font(.caption)
                                    .foregroundStyle(AppColors.connected)
                            } else {
                                Text("No iCloud Account")
                                    .font(.caption)
                                    .foregroundStyle(AppColors.warning)
                            }
                        }
                        HStack {
                            Label("Keychain Sync", systemImage: "key.icloud")
                            Spacer()
                            Text("Passwords")
                                .font(.caption)
                                .foregroundStyle(AppColors.textSecondary)
                        }
                    }
                } header: {
                    Label("Sync", systemImage: "arrow.triangle.2.circlepath")
                } footer: {
                    if cloudSyncEnabled {
                        Text("Connection profiles sync via iCloud. Passwords sync via iCloud Keychain. Private keys stay on-device.")
                    } else {
                        Text("All data is stored locally on this device only. Turn on to sync across iPhone, iPad, and Mac.")
                    }
                }
                .alert("Restart Required", isPresented: $showRestartAlert) {
                    Button("OK") {}
                } message: {
                    Text("Please restart mSSH for the sync change to take effect.")
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
                    Text("Removes all connections, keys, and known hosts from this device.")
                }
                .alert("Clear All Data?", isPresented: $showClearDataAlert) {
                    Button("Cancel", role: .cancel) {}
                    Button("Clear Everything", role: .destructive) {
                        clearAllData()
                    }
                } message: {
                    Text("This will delete all connections, SSH keys, and known hosts. This cannot be undone.")
                }

                // About
                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(AppColors.textSecondary)
                    }
                    HStack {
                        Text("Build")
                        Spacer()
                        Text("1")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(AppColors.textSecondary)
                    }
                } header: {
                    Label("About", systemImage: "info.circle")
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
        }
        .appTheme()
    }

    private func clearAllData() {
        let context = modelContext
        do {
            try context.delete(model: ConnectionProfile.self)
            try context.delete(model: SSHKey.self)
            try context.delete(model: KnownHost.self)
            try context.save()
        } catch {
            print("[mSSH] Failed to clear data: \(error)")
        }
    }
}
