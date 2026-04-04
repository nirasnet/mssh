import SwiftUI
import SwiftData

/// First-run setup wizard that guides users through:
/// 1. Welcome
/// 2. Storage mode (iCloud vs Local)
/// 3. Import SSH config & keys
/// 4. Summary
struct WelcomeView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("cloudSyncEnabled") private var cloudSyncEnabled = true
    @State private var step = 0
    @State private var importedConnections = 0
    @State private var importedKeys = 0
    @State private var isImporting = false
    @State private var importDone = false
    #if os(macOS)
    @State private var detectedHosts: [String] = []
    #endif

    let onComplete: () -> Void

    private let totalSteps = 4

    var body: some View {
        VStack(spacing: 0) {
            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(AppColors.border)
                        .frame(height: 3)
                    Rectangle()
                        .fill(AppColors.accent)
                        .frame(width: geo.size.width * CGFloat(step + 1) / CGFloat(totalSteps), height: 3)
                        .animation(.easeInOut(duration: 0.3), value: step)
                }
            }
            .frame(height: 3)

            // Content
            Group {
                switch step {
                case 0: welcomeStep
                case 1: storageStep
                case 2: importStep
                case 3: summaryStep
                default: summaryStep
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Bottom navigation
            HStack {
                if step > 0 {
                    Button {
                        withAnimation { step -= 1 }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.caption)
                            Text("Back")
                        }
                        .font(.system(.subheadline, design: .monospaced))
                        .foregroundStyle(AppColors.textSecondary)
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                if step < totalSteps - 1 {
                    Button {
                        withAnimation { step += 1 }
                    } label: {
                        HStack(spacing: 4) {
                            Text(step == 0 ? "Get Started" : "Next")
                            Image(systemName: "chevron.right")
                                .font(.caption)
                        }
                        .font(.system(.subheadline, design: .monospaced).weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, AppSpacing.xl)
                        .padding(.vertical, AppSpacing.sm)
                        .background(AppColors.accent)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                } else {
                    Button {
                        onComplete()
                    } label: {
                        HStack(spacing: 4) {
                            Text("Open mSSH")
                            Image(systemName: "arrow.right")
                                .font(.caption)
                        }
                        .font(.system(.subheadline, design: .monospaced).weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, AppSpacing.xl)
                        .padding(.vertical, AppSpacing.sm)
                        .background(AppColors.accent)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, AppSpacing.xl)
            .padding(.vertical, AppSpacing.lg)
        }
        .background(AppColors.background)
        #if os(macOS)
        .onAppear { detectSSHConfig() }
        #endif
    }

    // MARK: - Step 1: Welcome

    private var welcomeStep: some View {
        VStack(spacing: AppSpacing.xl) {
            Spacer()

            Image(systemName: "terminal.fill")
                .font(.system(size: 56))
                .foregroundStyle(AppColors.accent)

            Text("Welcome to mSSH")
                .font(.system(.title, design: .monospaced).weight(.bold))
                .foregroundStyle(AppColors.textPrimary)

            Text("A fast, secure SSH terminal\nfor all your Apple devices.")
                .font(.body)
                .foregroundStyle(AppColors.textSecondary)
                .multilineTextAlignment(.center)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AppSpacing.lg) {
                featureCard(icon: "key.fill", title: "SSH Keys", color: AppColors.accent)
                featureCard(icon: "lock.shield.fill", title: "TOFU", color: AppColors.connected)
                featureCard(icon: "rectangle.stack.fill", title: "Multi-Tab", color: AppColors.warning)
                featureCard(icon: "folder.fill", title: "SFTP", color: .purple)
            }
            .padding(.horizontal, AppSpacing.xxl * 2)

            Spacer()
        }
    }

    // MARK: - Step 2: Storage Choice

    private var storageStep: some View {
        VStack(spacing: AppSpacing.xl) {
            Spacer()

            Image(systemName: cloudSyncEnabled ? "icloud.fill" : "internaldrive.fill")
                .font(.system(size: 48))
                .foregroundStyle(AppColors.accent)
                .animation(.easeInOut, value: cloudSyncEnabled)

            Text("Where to store data?")
                .font(.system(.title2, design: .monospaced).weight(.bold))
                .foregroundStyle(AppColors.textPrimary)

            VStack(spacing: AppSpacing.md) {
                storageOption(
                    icon: "icloud.fill",
                    title: "iCloud Sync",
                    desc: "Sync connections across iPhone, iPad & Mac.\nPasswords sync via iCloud Keychain.\nPrivate keys stay on each device.",
                    isSelected: cloudSyncEnabled
                ) {
                    withAnimation { cloudSyncEnabled = true }
                }

                storageOption(
                    icon: "internaldrive.fill",
                    title: "Local Only",
                    desc: "Everything stays on this device.\nNo cloud. No sync. Full privacy.",
                    isSelected: !cloudSyncEnabled
                ) {
                    withAnimation { cloudSyncEnabled = false }
                }
            }
            .padding(.horizontal, AppSpacing.xxl)

            Spacer()
        }
    }

    // MARK: - Step 3: Import

    private var importStep: some View {
        VStack(spacing: AppSpacing.xl) {
            Spacer()

            #if os(macOS)
            macImportContent
            #else
            iosImportContent
            #endif

            Spacer()
        }
    }

    #if os(macOS)
    private var macImportContent: some View {
        VStack(spacing: AppSpacing.xl) {
            Image(systemName: importDone ? "checkmark.circle.fill" : "square.and.arrow.down.fill")
                .font(.system(size: 48))
                .foregroundStyle(importDone ? AppColors.connected : AppColors.accent)

            Text(importDone ? "Import Complete" : "Import SSH Config")
                .font(.system(.title2, design: .monospaced).weight(.bold))
                .foregroundStyle(AppColors.textPrimary)

            if importDone {
                VStack(spacing: AppSpacing.sm) {
                    resultRow(icon: "server.rack", text: "\(importedConnections) connections imported")
                    resultRow(icon: "key.fill", text: "\(importedKeys) SSH keys imported")
                    if cloudSyncEnabled {
                        resultRow(icon: "icloud.fill", text: "Will sync to your other devices")
                    }
                }
            } else if !detectedHosts.isEmpty {
                VStack(spacing: AppSpacing.sm) {
                    Text("Detected \(detectedHosts.count) hosts in ~/.ssh/config:")
                        .font(.caption)
                        .foregroundStyle(AppColors.textSecondary)

                    VStack(spacing: 4) {
                        ForEach(detectedHosts.prefix(8), id: \.self) { host in
                            HStack(spacing: AppSpacing.sm) {
                                Image(systemName: "server.rack")
                                    .font(.system(size: 10))
                                    .foregroundStyle(AppColors.accent)
                                Text(host)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(AppColors.textPrimary)
                                Spacer()
                            }
                        }
                        if detectedHosts.count > 8 {
                            Text("+ \(detectedHosts.count - 8) more")
                                .font(.caption)
                                .foregroundStyle(AppColors.textTertiary)
                        }
                    }
                    .padding(AppSpacing.md)
                    .background(AppColors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .padding(.horizontal, AppSpacing.xxl)

                Button {
                    performMacImport()
                } label: {
                    HStack {
                        if isImporting {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Text(isImporting ? "Importing..." : "Import All")
                            .font(.system(.body, design: .monospaced).weight(.semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, AppSpacing.xxl)
                    .padding(.vertical, AppSpacing.md)
                    .background(AppColors.accent)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(isImporting)
            } else {
                Text("No ~/.ssh/config found on this Mac.")
                    .font(.body)
                    .foregroundStyle(AppColors.textSecondary)

                Text("You can add connections manually after setup.")
                    .font(.caption)
                    .foregroundStyle(AppColors.textTertiary)
            }
        }
    }
    #endif

    #if os(iOS)
    private var iosImportContent: some View {
        VStack(spacing: AppSpacing.xl) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 48))
                .foregroundStyle(AppColors.accent)

            Text("Ready to Connect")
                .font(.system(.title2, design: .monospaced).weight(.bold))
                .foregroundStyle(AppColors.textPrimary)

            VStack(alignment: .leading, spacing: AppSpacing.md) {
                tipRow(icon: "bolt.fill", text: "Quick Connect: type user@host to connect")
                tipRow(icon: "plus.circle.fill", text: "Save connections for easy access")
                tipRow(icon: "doc.text.fill", text: "Import SSH config from Files app")
                if cloudSyncEnabled {
                    tipRow(icon: "laptopcomputer", text: "Import on Mac — syncs here automatically")
                }
            }
            .padding(.horizontal, AppSpacing.xxl)
        }
    }
    #endif

    // MARK: - Step 4: Summary

    private var summaryStep: some View {
        VStack(spacing: AppSpacing.xl) {
            Spacer()

            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 56))
                .foregroundStyle(AppColors.connected)

            Text("You're All Set")
                .font(.system(.title, design: .monospaced).weight(.bold))
                .foregroundStyle(AppColors.textPrimary)

            VStack(spacing: AppSpacing.md) {
                summaryRow(
                    icon: cloudSyncEnabled ? "icloud.fill" : "internaldrive.fill",
                    label: "Storage",
                    value: cloudSyncEnabled ? "iCloud Sync" : "Local Only"
                )
                if importedConnections > 0 {
                    summaryRow(icon: "server.rack", label: "Connections", value: "\(importedConnections)")
                }
                if importedKeys > 0 {
                    summaryRow(icon: "key.fill", label: "SSH Keys", value: "\(importedKeys)")
                }
                summaryRow(
                    icon: "terminal.fill",
                    label: "Ready",
                    value: "Let's go!"
                )
            }
            .padding(AppSpacing.lg)
            .background(AppColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, AppSpacing.xxl)

            Text("You can change these settings anytime.")
                .font(.caption)
                .foregroundStyle(AppColors.textTertiary)

            Spacer()
        }
    }

    // MARK: - macOS Import Logic

    #if os(macOS)
    private func detectSSHConfig() {
        let configURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".ssh/config")
        guard let data = try? Data(contentsOf: configURL),
              let text = String(data: data, encoding: .utf8) else { return }

        let entries = SSHConfigParser.parse(text)
        detectedHosts = SSHConfigParser.concreteHosts(from: entries).map(\.hostAlias)
    }

    private func performMacImport() {
        isImporting = true
        let fm = FileManager.default
        let sshDir = fm.homeDirectoryForCurrentUser.appendingPathComponent(".ssh")
        let configURL = sshDir.appendingPathComponent("config")

        guard let data = try? Data(contentsOf: configURL),
              let text = String(data: data, encoding: .utf8) else {
            isImporting = false
            return
        }

        let entries = SSHConfigParser.parse(text)
        let hosts = SSHConfigParser.concreteHosts(from: entries)

        // Import keys
        var keyMap: [String: String] = [:]
        for host in hosts {
            let resolved = SSHConfigParser.resolve(host, withDefaults: entries)
            guard let identityFile = resolved.identityFile else { continue }

            let expandedPath: String
            if identityFile.hasPrefix("~/") {
                expandedPath = fm.homeDirectoryForCurrentUser.path + String(identityFile.dropFirst(1))
            } else {
                expandedPath = identityFile
            }

            guard keyMap[expandedPath] == nil,
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
            let sshKey = SSHKey(
                label: URL(fileURLWithPath: expandedPath).lastPathComponent,
                keyType: keyType,
                keychainID: keychainID,
                publicKeyText: "(imported from Mac)"
            )
            modelContext.insert(sshKey)
            keyMap[expandedPath] = keychainID
            importedKeys += 1
        }

        // Create connections
        for host in hosts {
            let resolved = SSHConfigParser.resolve(host, withDefaults: entries)
            var keyID: String?
            if let identityFile = resolved.identityFile {
                let expandedPath: String
                if identityFile.hasPrefix("~/") {
                    expandedPath = fm.homeDirectoryForCurrentUser.path + String(identityFile.dropFirst(1))
                } else {
                    expandedPath = identityFile
                }
                keyID = keyMap[expandedPath]
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
            importedConnections += 1
        }

        try? modelContext.save()
        UserDefaults.standard.set(true, forKey: "autoImportComplete")

        withAnimation {
            isImporting = false
            importDone = true
            // Auto-advance to summary
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                withAnimation { step = 3 }
            }
        }
    }
    #endif

    // MARK: - UI Components

    private func featureCard(icon: String, title: String, color: Color) -> some View {
        VStack(spacing: AppSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundStyle(color)
            Text(title)
                .font(.system(.caption, design: .monospaced).weight(.medium))
                .foregroundStyle(AppColors.textPrimary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.md)
        .background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func storageOption(icon: String, title: String, desc: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.md) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundStyle(isSelected ? AppColors.accent : AppColors.textTertiary)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(.subheadline, design: .monospaced).weight(.semibold))
                        .foregroundStyle(AppColors.textPrimary)
                    Text(desc)
                        .font(.caption)
                        .foregroundStyle(AppColors.textSecondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? AppColors.accent : AppColors.textTertiary)
            }
            .padding(AppSpacing.md)
            .background(isSelected ? AppColors.accentDim : AppColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(isSelected ? AppColors.accent.opacity(0.5) : AppColors.border, lineWidth: isSelected ? 1.5 : 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    private func resultRow(icon: String, text: String) -> some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(AppColors.connected)
                .frame(width: 20)
            Text(text)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(AppColors.textPrimary)
        }
    }

    private func tipRow(icon: String, text: String) -> some View {
        HStack(spacing: AppSpacing.md) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(AppColors.accent)
                .frame(width: 24)
            Text(text)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(AppColors.textSecondary)
        }
    }

    private func summaryRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: AppSpacing.md) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(AppColors.accent)
                .frame(width: 20)
            Text(label)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(AppColors.textSecondary)
            Spacer()
            Text(value)
                .font(.system(.caption, design: .monospaced).weight(.semibold))
                .foregroundStyle(AppColors.textPrimary)
        }
    }
}
