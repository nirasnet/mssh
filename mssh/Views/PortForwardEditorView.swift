import SwiftUI
import SwiftData

/// Sheet for creating or editing a single `PortForward` rule attached to a
/// specific profile (identified by its stable `syncID`).
struct PortForwardEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let profileSyncID: String
    let existing: PortForward?

    @State private var localHost: String = "127.0.0.1"
    @State private var localPort: String = ""
    @State private var remoteHost: String = ""
    @State private var remotePort: String = ""
    @State private var enabled: Bool = true

    private var parsedLocalPort: Int? {
        guard let p = Int(localPort), p >= 1, p <= 65535 else { return nil }
        return p
    }

    private var parsedRemotePort: Int? {
        guard let p = Int(remotePort), p >= 1, p <= 65535 else { return nil }
        return p
    }

    private var isValid: Bool {
        parsedLocalPort != nil
            && parsedRemotePort != nil
            && !remoteHost.trimmingCharacters(in: .whitespaces).isEmpty
            && !localHost.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle(isOn: $enabled) {
                        Label("Enabled", systemImage: enabled ? "checkmark.circle.fill" : "circle")
                    }
                    .tint(AppColors.accent)
                } footer: {
                    Text("Disabled rules stay saved but are skipped on connect.")
                }

                Section {
                    TextField("Bind host", text: $localHost, prompt: Text("127.0.0.1").foregroundStyle(AppColors.textTertiary))
                        .iOSOnlyTextInputAutocapitalization()
                        .autocorrectionDisabled()
                        #if os(iOS)
                        .keyboardType(.URL)
                        #endif
                    TextField("Local port", text: $localPort, prompt: Text("e.g. 8080").foregroundStyle(AppColors.textTertiary))
                        .iOSOnlyTextInputAutocapitalization()
                        .autocorrectionDisabled()
                        #if os(iOS)
                        .keyboardType(.numberPad)
                        #endif
                } header: {
                    Text("Listen on (this device)")
                } footer: {
                    Text("127.0.0.1 binds to loopback only — recommended.")
                }

                Section {
                    TextField("Remote host", text: $remoteHost, prompt: Text("e.g. localhost or 10.0.0.5").foregroundStyle(AppColors.textTertiary))
                        .iOSOnlyTextInputAutocapitalization()
                        .autocorrectionDisabled()
                        #if os(iOS)
                        .keyboardType(.URL)
                        #endif
                    TextField("Remote port", text: $remotePort, prompt: Text("e.g. 80").foregroundStyle(AppColors.textTertiary))
                        .iOSOnlyTextInputAutocapitalization()
                        .autocorrectionDisabled()
                        #if os(iOS)
                        .keyboardType(.numberPad)
                        #endif
                } header: {
                    Text("Forward to (from server)")
                } footer: {
                    Text("Resolved on the SSH server side. \"localhost\" means localhost relative to the server, not your device.")
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppColors.background)
            .navigationTitle(existing == nil ? "New Forward" : "Edit Forward")
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
                    .disabled(!isValid)
                }
            }
            .onAppear {
                if let e = existing {
                    localHost = e.localHost
                    localPort = String(e.localPort)
                    remoteHost = e.remoteHost
                    remotePort = String(e.remotePort)
                    enabled = e.enabled
                }
            }
        }
        .appTheme()
    }

    private func save() {
        guard let lp = parsedLocalPort, let rp = parsedRemotePort else { return }
        let trimmedRemote = remoteHost.trimmingCharacters(in: .whitespaces)
        let trimmedLocal = localHost.trimmingCharacters(in: .whitespaces)

        if let existing {
            existing.localHost = trimmedLocal.isEmpty ? "127.0.0.1" : trimmedLocal
            existing.localPort = lp
            existing.remoteHost = trimmedRemote
            existing.remotePort = rp
            existing.enabled = enabled
        } else {
            let new = PortForward(
                profileSyncID: profileSyncID,
                kind: "local",
                localHost: trimmedLocal.isEmpty ? "127.0.0.1" : trimmedLocal,
                localPort: lp,
                remoteHost: trimmedRemote,
                remotePort: rp,
                enabled: enabled
            )
            modelContext.insert(new)
        }
        try? modelContext.save()
    }
}

/// Compact list of port-forward rules for a single profile, plus an "Add"
/// row that opens `PortForwardEditorView`. Used inside `ConnectionFormView`.
struct PortForwardListSection: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allForwards: [PortForward]

    let profileSyncID: String

    @State private var editingForward: PortForward?
    @State private var showCreateSheet = false

    private var forwards: [PortForward] {
        allForwards
            .filter { $0.profileSyncID == profileSyncID }
            .sorted { $0.localPort < $1.localPort }
    }

    var body: some View {
        Section {
            if forwards.isEmpty {
                Text("No port forwards configured.")
                    .font(.caption)
                    .foregroundStyle(AppColors.textSecondary)
            } else {
                ForEach(forwards) { forward in
                    Button {
                        editingForward = forward
                    } label: {
                        HStack(spacing: AppSpacing.sm) {
                            Image(systemName: forward.enabled ? "arrow.left.arrow.right.circle.fill" : "arrow.left.arrow.right.circle")
                                .foregroundStyle(forward.enabled ? AppColors.accent : AppColors.textTertiary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(forward.localHost):\(forward.localPort)")
                                    .font(.system(.subheadline, design: .monospaced))
                                    .foregroundStyle(AppColors.textPrimary)
                                Text("→ \(forward.remoteHost):\(forward.remotePort)")
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(AppColors.textSecondary)
                            }
                            Spacer()
                            if !forward.enabled {
                                Text("OFF")
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                    .foregroundStyle(AppColors.textTertiary)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1)
                                    .background(AppColors.surfaceElevated)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            modelContext.delete(forward)
                            try? modelContext.save()
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }

            Button {
                showCreateSheet = true
            } label: {
                Label("Add Port Forward", systemImage: "plus.circle")
                    .foregroundStyle(AppColors.accent)
            }
        } header: {
            Text("Port Forwarding")
        } footer: {
            Text("Local forwarding tunnels a port on this device through the SSH connection to a host reachable from the server.")
        }
        .sheet(isPresented: $showCreateSheet) {
            PortForwardEditorView(profileSyncID: profileSyncID, existing: nil)
        }
        .sheet(item: $editingForward) { forward in
            PortForwardEditorView(profileSyncID: profileSyncID, existing: forward)
        }
    }
}
