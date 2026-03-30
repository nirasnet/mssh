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

    private var viewModel = ConnectionListViewModel()

    init(existingProfile: ConnectionProfile? = nil) {
        self.existingProfile = existingProfile
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Server") {
                    TextField("Label", text: $label)
                        .textInputAutocapitalization(.never)
                    TextField("Host", text: $host)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                    TextField("Port", text: $port)
                        .keyboardType(.numberPad)
                    TextField("Username", text: $username)
                        .textInputAutocapitalization(.never)
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
                        if keys.isEmpty {
                            NavigationLink("Manage Keys") {
                                KeyManagerView()
                            }
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
                    .disabled(host.isEmpty || username.isEmpty)
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

    private func save() {
        let portInt = Int(port) ?? 22
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
