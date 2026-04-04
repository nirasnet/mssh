import SwiftUI
import SwiftData

struct ConnectionFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var keys: [SSHKey]

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
                                .tag(Optional(key.keychainID))
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
                    selectedKeyID = p.keyID
                }
            }
        }
        .appTheme()
    }

    // MARK: - Helpers

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

    private func testConnection() {
        guard !host.isEmpty, !username.isEmpty, let portInt = parsedPort else { return }
        isTestingConnection = true
        testResult = nil

        Task {
            do {
                let _ = try await withThrowingTaskGroup(of: Bool.self) { group in
                    group.addTask {
                        let _ = try await URLSession.shared.bytes(
                            from: URL(string: "http://\(host):\(portInt)")!
                        )
                        return true
                    }
                    group.addTask {
                        try await Task.sleep(for: .seconds(5))
                        throw CancellationError()
                    }
                    let result = try await group.next() ?? false
                    group.cancelAll()
                    return result
                }
                testResult = ConnectionTestResult(
                    success: true,
                    message: "\(host):\(portInt) reachable"
                )
            } catch {
                let errorDesc = error.localizedDescription.lowercased()
                if errorDesc.contains("refused") || errorDesc.contains("reset") {
                    testResult = ConnectionTestResult(
                        success: true,
                        message: "\(host):\(portInt) reachable (port responded)"
                    )
                } else {
                    testResult = ConnectionTestResult(
                        success: false,
                        message: "Cannot reach \(host):\(portInt)"
                    )
                }
            }
            isTestingConnection = false
        }
    }

    private func save() {
        let portInt = parsedPort ?? 22
        let effectiveLabel = label.isEmpty ? "\(username)@\(host)" : label
        viewModel.saveConnection(
            profile: existingProfile,
            label: effectiveLabel,
            host: host,
            port: portInt,
            username: username,
            authType: authType,
            password: authType == .password ? password : nil,
            keyID: authType == .key ? selectedKeyID : nil,
            modelContext: modelContext
        )
    }
}

private struct ConnectionTestResult {
    let success: Bool
    let message: String
}
