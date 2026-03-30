import SwiftUI
import SwiftData

struct KnownHostsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \KnownHost.host) private var knownHosts: [KnownHost]

    @State private var selectedHost: KnownHost?
    @State private var showDeleteConfirmation = false
    @State private var hostToDelete: KnownHost?

    var body: some View {
        List {
            if knownHosts.isEmpty {
                ContentUnavailableView(
                    "No Known Hosts",
                    systemImage: "server.rack",
                    description: Text("Host keys will appear here after your first connection to a server.")
                )
            } else {
                ForEach(knownHosts) { host in
                    KnownHostRow(host: host)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedHost = host
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                hostToDelete = host
                                showDeleteConfirmation = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
            }
        }
        .navigationTitle("Known Hosts")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if !knownHosts.isEmpty {
                    EditButton()
                }
            }
        }
        .sheet(item: $selectedHost) { host in
            KnownHostDetailView(host: host)
        }
        .confirmationDialog(
            "Remove Known Host",
            isPresented: $showDeleteConfirmation,
            presenting: hostToDelete
        ) { host in
            Button("Remove", role: .destructive) {
                deleteHost(host)
            }
        } message: { host in
            Text("Remove the trusted key for \(host.host):\(host.port)? You will be prompted to verify the key on the next connection.")
        }
    }

    private func deleteHost(_ host: KnownHost) {
        KeychainService.deleteItem(account: "hostkey-\(host.host):\(host.port)")
        modelContext.delete(host)
        try? modelContext.save()
    }
}

// MARK: - Row

private struct KnownHostRow: View {
    let host: KnownHost

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(host.host)
                    .font(.body.bold())
                if host.port != 22 {
                    Text(":\(host.port)")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(host.keyTypeDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.quaternary)
                    .clipShape(Capsule())
            }

            Text(host.fingerprintSHA256)
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Detail Sheet

private struct KnownHostDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let host: KnownHost

    var body: some View {
        NavigationStack {
            List {
                Section("Connection") {
                    LabeledContent("Host", value: host.host)
                    LabeledContent("Port", value: "\(host.port)")
                }

                Section("Key") {
                    LabeledContent("Type", value: host.keyTypeDescription)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Fingerprint")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(host.fingerprintSHA256)
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                    }
                }

                Section("History") {
                    LabeledContent("First seen") {
                        Text(host.firstSeenAt, style: .date)
                    }
                    LabeledContent("Last seen") {
                        Text(host.lastSeenAt, style: .date)
                    }
                }
            }
            .navigationTitle("Host Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
