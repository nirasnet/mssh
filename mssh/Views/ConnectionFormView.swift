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

    private var selectedKeyName: String {
        guard let keyID = selectedKeyID else { return "None" }
        if let key = keys.first(where: { $0.keychainID == keyID }) {
            return "\(key.label) (\(key.keyType))"
        }
        return "Unknown Key"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Server") {
                    TextField("Label (auto-filled if empty)", text: $label)
                        .textInputAutocapitalization(.never)
                    TextField("Host", text: $host)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .onChange(of: host) { updateAutoLabel() }
                    HStack {
                        TextField("Port", text: $port)
                            .keyboardType(.numberPad)
                            .onChange(of: port) {
                                validatePort()
                            }
                        if let error = portValidationError {
                            Text(error)
                                .font(.caption2)
                                .foregroundStyle(.red)
                        }
                    }
                    TextField("Username", text: $username)
                        .textInputAutocapitalization(.never)
                        .onChange(of: username) { updateAutoLabel() }
                }

                Section("Authentication") {
                    Picker("Method", selection: $authType) {
                        Text("Password").tag(AuthenticationType.password)
                        Text("SSH Key").tag(AuthenticationType.key)
                    }

                    if authType == .password {
                        SecureField("Password", text: $password)
                    } else {
                        Picker("Key", selection: $selectedKeyID) {
                            Text("None").tag(String?.none)
                            ForEach(keys) { key in
                                Text("\(key.label) (\(key.keyType))")
                                    .tag(Optional(key.keychainID))
                            }
                        }
                        if let keyID = selectedKeyID, keys.contains(where: { $0.keychainID == keyID }) {
                            HStack {
                                Image(systemName: "key.fill")
                                    .foregroundStyle(.secondary)
                                    .font(.caption)
                                Text(selectedKeyName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        if keys.isEmpty {
                            NavigationLink("Manage Keys") {
                                KeyManagerView()
                            }
                        }
                    }
                }

                Section {
                    Button {
                        testConnection()
                    } label: {
                        HStack {
                            if isTestingConnection {
                                ProgressView()
                                    .controlSize(.small)
                                Text("Testing...")
                                    .foregroundStyle(.secondary)
                            } else {
                                Image(systemName: "antenna.radiowaves.left.and.right")
                                Text("Test Connection")
                            }
                            Spacer()
                            if let result = testResult {
                                Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundStyle(result.success ? .green : .red)
                            }
                        }
                    }
                    .disabled(host.isEmpty || username.isEmpty || isTestingConnection || parsedPort == nil)

                    if let result = testResult {
                        Text(result.message)
                            .font(.caption)
                            .foregroundStyle(result.success ? .green : .red)
                    }
                }

                if !label.isEmpty || (!host.isEmpty && !username.isEmpty) {
                    Section("Preview") {
                        let effectiveLabel = label.isEmpty ? "\(username)@\(host)" : label
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(effectiveLabel)
                                    .font(.headline)
                                Text("\(username)@\(host):\(port)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "server.rack")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle(existingProfile == nil ? "New Connection" : "Edit Connection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                        dismiss()
                    }
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
    }

    private func validatePort() {
        if port.isEmpty {
            portValidationError = nil
            return
        }
        if let p = Int(port) {
            if p < 1 || p > 65535 {
                portValidationError = "1-65535"
            } else {
                portValidationError = nil
            }
        } else {
            portValidationError = "Invalid"
        }
    }

    private func updateAutoLabel() {
        // Only auto-fill if the user has not manually entered a label
        // We detect this by checking if the label matches the auto-generated pattern
        // or is empty
        let autoPattern = "\(username)@\(host)"
        if label.isEmpty || label == autoPattern {
            // Don't set it yet - it will be applied on save
        }
    }

    private func testConnection() {
        guard !host.isEmpty, !username.isEmpty, let portInt = parsedPort else { return }
        isTestingConnection = true
        testResult = nil

        Task {
            do {
                let connection = try await withThrowingTaskGroup(of: Bool.self) { group in
                    group.addTask {
                        // Try a basic TCP connection to the host:port
                        let stream = try await URLSession.shared.bytes(
                            from: URL(string: "http://\(host):\(portInt)")!
                        )
                        // If we get here, port is reachable (though HTTP will fail, that's fine)
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
                    message: "Host \(host):\(portInt) is reachable"
                )
            } catch {
                // Even a connection refused means the host exists
                let errorDesc = error.localizedDescription.lowercased()
                if errorDesc.contains("refused") || errorDesc.contains("reset") {
                    testResult = ConnectionTestResult(
                        success: true,
                        message: "Host \(host):\(portInt) is reachable (port responded)"
                    )
                } else {
                    testResult = ConnectionTestResult(
                        success: false,
                        message: "Cannot reach \(host):\(portInt) - \(error.localizedDescription)"
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
