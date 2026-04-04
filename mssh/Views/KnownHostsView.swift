import SwiftUI
import SwiftData

struct KnownHostsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \KnownHost.host) private var knownHosts: [KnownHost]

    @State private var selectedHost: KnownHost?
    @State private var showDeleteConfirmation = false
    @State private var hostToDelete: KnownHost?

    var body: some View {
        Group {
            if knownHosts.isEmpty {
                VStack(spacing: AppSpacing.md) {
                    Spacer()
                    Image(systemName: "server.rack")
                        .font(.system(size: 36))
                        .foregroundStyle(AppColors.textTertiary)
                    Text("No Known Hosts")
                        .font(AppFonts.subheading)
                        .foregroundStyle(AppColors.textSecondary)
                    Text("Host keys appear after your first connection")
                        .font(.caption)
                        .foregroundStyle(AppColors.textTertiary)
                    Spacer()
                }
            } else {
                ScrollView {
                    VStack(spacing: AppSpacing.sm) {
                        ForEach(knownHosts) { host in
                            Button {
                                selectedHost = host
                            } label: {
                                KnownHostRow(host: host)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button(role: .destructive) {
                                    hostToDelete = host
                                    showDeleteConfirmation = true
                                } label: {
                                    Label("Remove", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.top, AppSpacing.sm)
                }
            }
        }
        .background(AppColors.background)
        .navigationTitle("Known Hosts")
        .iOSOnlyNavigationBarTitleDisplayMode()
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
            Text("Remove the trusted key for \(host.host):\(host.port)? You'll be prompted to verify on next connection.")
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
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            HStack {
                Text(host.host)
                    .font(.system(.subheadline, design: .monospaced).weight(.medium))
                    .foregroundStyle(AppColors.textPrimary)
                if host.port != 22 {
                    Text(":\(host.port)")
                        .font(.system(.subheadline, design: .monospaced))
                        .foregroundStyle(AppColors.textSecondary)
                }
                Spacer()
                Text(host.keyTypeDescription)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(AppColors.accent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(AppColors.accentDim)
                    .clipShape(Capsule())
            }

            Text(host.fingerprintSHA256)
                .font(AppFonts.monoCaption)
                .foregroundStyle(AppColors.textTertiary)
                .lineLimit(1)
                .truncationMode(.middle)

            HStack(spacing: AppSpacing.md) {
                Text("First: \(host.firstSeenAt.formatted(.relative(presentation: .named)))")
                Text("Last: \(host.lastSeenAt.formatted(.relative(presentation: .named)))")
            }
            .font(.system(size: 10))
            .foregroundStyle(AppColors.textTertiary)
        }
        .appCard()
    }
}

// MARK: - Detail Sheet

private struct KnownHostDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let host: KnownHost

    var body: some View {
        NavigationStack {
            Form {
                Section("Connection") {
                    LabeledContent("Host", value: host.host)
                    LabeledContent("Port", value: "\(host.port)")
                }

                Section("Key") {
                    LabeledContent("Type", value: host.keyTypeDescription)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Fingerprint")
                            .font(.caption)
                            .foregroundStyle(AppColors.textSecondary)
                        Text(host.fingerprintSHA256)
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(AppColors.textPrimary)
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
            .scrollContentBackground(.hidden)
            .background(AppColors.background)
            .navigationTitle("Host Details")
            .iOSOnlyNavigationBarTitleDisplayMode()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.medium)
                }
            }
        }
        .appTheme()
    }
}
