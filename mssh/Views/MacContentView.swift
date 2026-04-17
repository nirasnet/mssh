#if os(macOS)
import SwiftUI
import SwiftData

/// macOS-specific root view. The full `ContentView` (TabView + NavigationSplitView
/// + .searchable + complex sections) triggers a recursive
/// `NSHostingView._informContainerThatSubviewsNeedUpdateConstraints` crash
/// on macOS 26.3 during the initial window layout animation. This stripped-
/// down variant uses a simple NavigationSplitView sidebar without nested
/// containers so AppKit's layout pass stays flat.
struct MacContentView: View {
    @Environment(SessionManager.self) private var sessionManager
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [
        SortDescriptor(\ConnectionProfile.lastConnectedAt, order: .reverse)
    ]) private var connections: [ConnectionProfile]
    @Query private var keys: [SSHKey]

    @State private var selectedView: MacSidebarItem? = .connections
    @State private var editingProfile: ConnectionProfile?
    @State private var showAddConnection = false
    @State private var showImportConfig = false

    @State private var syncMessage: String?
    @State private var showSyncAlert = false

    enum MacSidebarItem: String, Hashable, CaseIterable {
        case connections = "Connections"
        case keys = "Keys"
        case settings = "Settings"
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedView) {
                Section("SSH") {
                    Label("Connections", systemImage: "server.rack")
                        .tag(MacSidebarItem.connections)
                    Label("Keys", systemImage: "key.fill")
                        .tag(MacSidebarItem.keys)
                }
                Section {
                    Label("Settings", systemImage: "gear")
                        .tag(MacSidebarItem.settings)
                }

                Section("Sync") {
                    Button {
                        let r = ConnectionSyncBridge.push(modelContext: modelContext)
                        syncMessage = "Pushed \(r.connections) connections, \(r.snippets) snippets, \(r.keys) keys to iCloud."
                        showSyncAlert = true
                    } label: {
                        Label("Push to iCloud", systemImage: "icloud.and.arrow.up")
                    }

                    Button {
                        let r = ConnectionSyncBridge.pull(modelContext: modelContext)
                        syncMessage = "Pulled \(r.connections) new connections, \(r.snippets) new snippets, \(r.keys) new keys from iCloud."
                        showSyncAlert = true
                    } label: {
                        Label("Pull from iCloud", systemImage: "icloud.and.arrow.down")
                    }

                    Button {
                        let r = SSHFolderImporter.promptAndImport(modelContext: modelContext)
                        syncMessage = r.humanSummary
                        showSyncAlert = true
                    } label: {
                        Label("Import ~/.ssh", systemImage: "square.and.arrow.down.on.square")
                    }
                }

                if !sessionManager.sessions.isEmpty {
                    Section("Active Sessions") {
                        ForEach(sessionManager.sessions) { session in
                            Button {
                                sessionManager.activeSessionID = session.id
                                selectedView = nil
                            } label: {
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(session.isConnected ? AppColors.connected : AppColors.textTertiary)
                                        .frame(width: 7, height: 7)
                                    Text(session.title)
                                        .font(.system(.body, design: .monospaced))
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("mSSH")
            .toolbar {
                ToolbarItem {
                    Menu {
                        Button { showAddConnection = true } label: {
                            Label("New Connection", systemImage: "plus")
                        }
                        Button { showImportConfig = true } label: {
                            Label("Import SSH Config", systemImage: "doc.text")
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        } detail: {
            Group {
                if selectedView == nil, let activeSession = sessionManager.activeSession {
                    TerminalSessionView(session: activeSession)
                } else {
                    switch selectedView {
                    case .connections:
                        macConnectionsList
                    case .keys:
                        KeyManagerView()
                    case .settings:
                        SettingsView()
                    case nil:
                        Text("Select a connection or use ⌘N to create one.")
                            .foregroundStyle(AppColors.textSecondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppColors.background)
        }
        .sheet(isPresented: $showAddConnection) {
            ConnectionFormView(existingProfile: nil)
        }
        .sheet(item: $editingProfile) { profile in
            ConnectionFormView(existingProfile: profile)
        }
        .sheet(isPresented: $showImportConfig) {
            SSHConfigImportView()
        }
        .appTheme()
        .alert("Sync", isPresented: $showSyncAlert) {
            Button("OK") {}
        } message: {
            Text(syncMessage ?? "")
        }
    }

    // MARK: - Connections list (flat, no sections/searchable)

    private var macConnectionsList: some View {
        List {
            ForEach(connections) { connection in
                Button {
                    connect(to: connection)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "server.rack")
                            .font(.system(size: 14))
                            .foregroundStyle(AppColors.accent)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(connection.label)
                                .font(.system(.body, design: .monospaced).weight(.medium))
                            Text("\(connection.username)@\(connection.host):\(connection.port)")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(AppColors.textSecondary)
                        }
                        Spacer()
                        if connection.isFavorite {
                            Image(systemName: "star.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(.yellow)
                        }
                        Image(systemName: connection.authType == .key ? "key.fill" : "lock.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(AppColors.textTertiary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button { connect(to: connection) } label: {
                        Label("Connect", systemImage: "bolt.fill")
                    }
                    Button { editingProfile = connection } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    Button {
                        connection.isFavorite.toggle()
                        try? modelContext.save()
                    } label: {
                        Label(connection.isFavorite ? "Unfavorite" : "Favorite", systemImage: "star")
                    }
                    Divider()
                    Button(role: .destructive) {
                        modelContext.delete(connection)
                        try? modelContext.save()
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
        .navigationTitle("Connections")
    }

    private func connect(to profile: ConnectionProfile) {
        let session = sessionManager.createSession(for: profile)
        session.modelContainer = modelContext.container
        sessionManager.activeSessionID = session.id
        selectedView = nil
        Task { await session.connect() }
    }
}
#endif
