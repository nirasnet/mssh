import SwiftUI
import SwiftData
import Network

struct ConnectionFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var keys: [SSHKey]
    @Query private var allConnections: [ConnectionProfile]

    let existingProfile: ConnectionProfile?

    @State private var label = ""
    @State private var host = ""
    @State private var port = "22"
    @State private var username = "root"
    @State private var authType: AuthenticationType = .password
    @State private var password = ""
    @State private var selectedKeyID: String?
    @State private var portValidationError: String?
    @State private var isTestingConnection = false
    @State private var testResult: ConnectionTestResult?

    // Organization fields (US-002)
    @State private var isFavorite: Bool = false
    @State private var groupName: String = ""
    @State private var colorTag: String? = nil

    private var existingGroupNames: [String] {
        ConnectionListSorter.existingGroupNames(allConnections)
    }

    private var viewModel = ConnectionListViewModel()

    init(existingProfile: ConnectionProfile? = nil) {
        self.existingProfile = existingProfile
    }

    private var parsedPort: Int? {
        guard let p = Int(port), p >= 1, p <= 65535 else { return nil }
        return p
    }

    private var isFormValid: Bool {
        !host.isEmpty && !username.isEmpty && parsedPort != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                // Server section
                Section {
                    formField("Label", text: $label, placeholder: "My Server", autocap: false)
                    #if os(iOS)
                    formField("Host", text: $host, placeholder: "192.168.1.1 or host.com", keyboard: UIKeyboardType.URL, autocap: false)
                    #else
                    formField("Host", text: $host, placeholder: "192.168.1.1 or host.com", autocap: false)
                    #endif
                    HStack {
                        #if os(iOS)
                        formField("Port", text: $port, placeholder: "22", keyboard: UIKeyboardType.numberPad)
                            .onChange(of: port) { validatePort() }
                        #else
                        formField("Port", text: $port, placeholder: "22")
                            .onChange(of: port) { validatePort() }
                        #endif
                        if let error = portValidationError {
                            Text(error)
                                .font(AppFonts.monoCaption)
                                .foregroundStyle(AppColors.error)
                        }
                    }
                    formField("Username", text: $username, placeholder: "root", autocap: false)
                } header: {
                    Text("Server")
                }

                // Authentication section
                Section {
                    Picker("Method", selection: $authType) {
                        Label("Password", systemImage: "lock.fill")
                            .tag(AuthenticationType.password)
                        Label("SSH Key", systemImage: "key.fill")
                            .tag(AuthenticationType.key)
                    }
                    .pickerStyle(.segmented)

                    if authType == .password {
                        SecureField("Password", text: $password)
                            .font(.system(.body, design: .monospaced))
                    } else {
                        Picker("Key", selection: $selectedKeyID) {
                            Text("Select a key...").tag(String?.none)
                            ForEach(keys) { key in
                                HStack {
                                    Text(key.label)
                                    Text("(\(key.keyType))")
                                        .foregroundStyle(.secondary)
                                }
                                // Tag by syncID (stable across devices) so a
                                // synced profile keeps pointing at the same
                                // key even after re-importing on a new device.
                                .tag(Optional(key.syncID))
                            }
                        }

                        if keys.isEmpty {
                            NavigationLink {
                                KeyManagerView()
                            } label: {
                                HStack {
                                    Image(systemName: "key.fill")
                                        .foregroundStyle(AppColors.accent)
                                    Text("Manage SSH Keys")
                                        .foregroundStyle(AppColors.accent)
                                }
                            }
                        }
                    }
                } header: {
                    Text("Authentication")
                }

                // Organization (Termius-style)
                Section {
                    Toggle(isOn: $isFavorite) {
                        Label("Favorite", systemImage: isFavorite ? "star.fill" : "star")
                    }
                    .tint(AppColors.accent)

                    HStack {
                        Image(systemName: "folder")
                            .foregroundStyle(AppColors.accent)
                        TextField("Group", text: $groupName, prompt: Text("e.g. Production").foregroundStyle(AppColors.textTertiary))
                            .iOSOnlyTextInputAutocapitalization()
                            .autocorrectionDisabled()
                        if !existingGroupNames.isEmpty {
                            Menu {
                                ForEach(existingGroupNames, id: \.self) { name in
                                    Button(name) { groupName = name }
                                }
                                if !groupName.isEmpty {
                                    Divider()
                                    Button("Clear", role: .destructive) { groupName = "" }
                                }
                            } label: {
                                Image(systemName: "chevron.down.circle")
                                    .foregroundStyle(AppColors.textSecondary)
                            }
                        }
                    }

                    HStack(spacing: AppSpacing.sm) {
                        Image(systemName: "tag")
                            .foregroundStyle(AppColors.accent)
                        Text("Color Tag")
                        Spacer()
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                tagSwatch(name: nil, isSelected: colorTag == nil)
                                ForEach(ConnectionProfile.tagPalette, id: \.self) { name in
                                    tagSwatch(name: name, isSelected: colorTag == name)
                                }
                            }
                        }
                    }
                } header: {
                    Text("Organization")
                }

                // Port forwarding (existing profiles only — needs a stable syncID)
                if let p = existingProfile {
                    PortForwardListSection(profileSyncID: p.syncID)
                }

                // Test connection
                Section {
                    Button {
                        testConnection()
                    } label: {
                        HStack {
                            if isTestingConnection {
                                ProgressView()
                                    .controlSize(.small)
                                    .tint(AppColors.accent)
                                Text("Testing...")
                                    .foregroundStyle(AppColors.textSecondary)
                            } else {
                                Image(systemName: "antenna.radiowaves.left.and.right")
                                    .foregroundStyle(AppColors.accent)
                                Text("Test Connection")
                            }
                            Spacer()
                            if let result = testResult {
                                Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundStyle(result.success ? AppColors.connected : AppColors.error)
                            }
                        }
                    }
                    .disabled(host.isEmpty || username.isEmpty || isTestingConnection || parsedPort == nil)

                    if let result = testResult {
                        Text(result.message)
                            .font(AppFonts.monoCaption)
                            .foregroundStyle(result.success ? AppColors.connected : AppColors.error)
                    }
                }

                // Preview
                if !host.isEmpty && !username.isEmpty {
                    Section("Preview") {
                        let effectiveLabel = label.isEmpty ? "\(username)@\(host)" : label
                        HStack(spacing: AppSpacing.md) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(AppColors.accentDim)
                                    .frame(width: 36, height: 36)
                                Image(systemName: "server.rack")
                                    .font(.system(size: 14))
                                    .foregroundStyle(AppColors.accent)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(effectiveLabel)
                                    .font(.system(.subheadline, design: .monospaced).weight(.medium))
                                Text("\(username)@\(host):\(port)")
                                    .font(AppFonts.monoCaption)
                                    .foregroundStyle(AppColors.textSecondary)
                            }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppColors.background)
            .navigationTitle(existingProfile == nil ? "New Connection" : "Edit Connection")
            .iOSOnlyNavigationBarTitleDisplayMode()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(!isFormValid)
                }
            }
            .onAppear {
                if let p = existingProfile {
                    label = p.label
                    host = p.host
                    port = String(p.port)
                    username = p.username
                    authType = p.authType
                    // Picker tags are SSHKey.syncID. Older profiles stored
                    // the device-specific keychainID — convert to syncID so
                    // the picker preselects correctly. Save() will then
                    // persist the syncID and the legacy value vanishes.
                    if let stored = p.keyID, !stored.isEmpty {
                        if keys.contains(where: { $0.syncID == stored }) {
                            selectedKeyID = stored
                        } else if let match = keys.first(where: { $0.keychainID == stored }) {
                            selectedKeyID = match.syncID
                        } else {
                            selectedKeyID = stored
                        }
                    } else {
                        selectedKeyID = nil
                    }
                    isFavorite = p.isFavorite
                    groupName = p.groupName ?? ""
                    colorTag = p.colorTag
                }
            }
        }
        .appTheme()
    }

    // MARK: - Helpers

    /// Small circular swatch for the color-tag picker. nil maps to a "no tag"
    /// dot (transparent with a stroke) so the user can also clear the tag.
    @ViewBuilder
    private func tagSwatch(name: String?, isSelected: Bool) -> some View {
        let resolved: Color = ConnectionProfile.tagColor(named: name) ?? .clear

        Button {
            colorTag = name
        } label: {
            ZStack {
                Circle()
                    .fill(resolved)
                    .frame(width: 22, height: 22)
                    .overlay(
                        Circle()
                            .strokeBorder(
                                name == nil ? AppColors.textTertiary : Color.white.opacity(0.2),
                                lineWidth: name == nil ? 1.0 : 0.5
                            )
                    )
                if name == nil {
                    Image(systemName: "slash.circle")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(AppColors.textSecondary)
                }
                if isSelected {
                    Circle()
                        .strokeBorder(AppColors.accent, lineWidth: 2)
                        .frame(width: 26, height: 26)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func formField(_ title: String, text: Binding<String>, placeholder: String = "", keyboard: Any? = nil, autocap: Bool = true) -> some View {
        TextField(title, text: text, prompt: Text(placeholder).foregroundStyle(AppColors.textTertiary))
            .font(.system(.body, design: .monospaced))
            .iOSOnlyTextInputAutocapitalization(autocap)
            .autocorrectionDisabled()
            .iOSOnlyKeyboardType(keyboard)
    }

    private func validatePort() {
        if port.isEmpty {
            portValidationError = nil
            return
        }
        if let p = Int(port) {
            portValidationError = (p < 1 || p > 65535) ? "1-65535" : nil
        } else {
            portValidationError = "Invalid"
        }
    }

    /// Real TCP reachability check (the old version did `URLSession.bytes` over
    /// HTTP against an SSH port — wrong protocol, so it always reported the
    /// SSH server as unreachable). NWConnection here does a raw TCP connect
    /// and, if it succeeds, reads up to 64 bytes of the server greeting so
    /// we can confidently report "SSH server detected" when the banner
    /// starts with "SSH-".
    private func testConnection() {
        guard !host.isEmpty, let portInt = parsedPort else { return }
        isTestingConnection = true
        testResult = nil

        Task {
            let result = await Self.probeTCP(host: host, port: portInt, timeout: 5)
            await MainActor.run {
                testResult = result
                isTestingConnection = false
            }
        }
    }

    private static func probeTCP(host: String, port: Int, timeout: TimeInterval) async -> ConnectionTestResult {
        await withCheckedContinuation { (continuation: CheckedContinuation<ConnectionTestResult, Never>) in
            guard let nwPort = NWEndpoint.Port(rawValue: UInt16(port)) else {
                continuation.resume(returning: ConnectionTestResult(success: false, message: "Invalid port \(port)"))
                return
            }

            let conn = NWConnection(host: NWEndpoint.Host(host), port: nwPort, using: .tcp)
            let queue = DispatchQueue.global(qos: .userInitiated)
            let lock = NSLock()
            var resumed = false

            func finish(_ result: ConnectionTestResult) {
                lock.lock()
                defer { lock.unlock() }
                guard !resumed else { return }
                resumed = true
                conn.cancel()
                continuation.resume(returning: result)
            }

            conn.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    // TCP handshake succeeded — try to read the SSH banner.
                    conn.receive(minimumIncompleteLength: 1, maximumLength: 64) { data, _, _, _ in
                        let banner = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
                        let trimmed = banner.trimmingCharacters(in: .whitespacesAndNewlines)
                        if trimmed.hasPrefix("SSH-") {
                            let summary = trimmed.split(separator: "\n").first.map(String.init) ?? trimmed
                            finish(ConnectionTestResult(success: true, message: "SSH server: \(summary)"))
                        } else if !banner.isEmpty {
                            finish(ConnectionTestResult(success: true, message: "Port \(port) reachable (no SSH banner)"))
                        } else {
                            finish(ConnectionTestResult(success: true, message: "Port \(port) reachable"))
                        }
                    }
                case .failed(let error):
                    let desc = "\(error)".lowercased()
                    let msg: String
                    if desc.contains("refused") {
                        msg = "Connection refused — \(port) is closed on \(host)"
                    } else if desc.contains("nodename") || desc.contains("not known") || desc.contains("hostnotfound") {
                        msg = "Cannot resolve host \(host)"
                    } else if desc.contains("network is unreachable") || desc.contains("no route") {
                        msg = "No network route to \(host)"
                    } else {
                        msg = "Cannot reach \(host):\(port)"
                    }
                    finish(ConnectionTestResult(success: false, message: msg))
                case .cancelled:
                    break
                default:
                    break
                }
            }

            conn.start(queue: queue)

            queue.asyncAfter(deadline: .now() + timeout) {
                finish(ConnectionTestResult(success: false, message: "Timed out after \(Int(timeout))s — host may be blocked by a firewall"))
            }
        }
    }

    private func save() {
        let portInt = parsedPort ?? 22
        let effectiveLabel = label.isEmpty ? "\(username)@\(host)" : label
        let trimmedGroup = groupName.trimmingCharacters(in: .whitespacesAndNewlines)
        viewModel.saveConnection(
            profile: existingProfile,
            label: effectiveLabel,
            host: host,
            port: portInt,
            username: username,
            authType: authType,
            password: authType == .password ? password : nil,
            keyID: authType == .key ? selectedKeyID : nil,
            isFavorite: isFavorite,
            groupName: trimmedGroup.isEmpty ? nil : trimmedGroup,
            colorTag: colorTag,
            modelContext: modelContext
        )
    }
}

private struct ConnectionTestResult {
    let success: Bool
    let message: String
}
