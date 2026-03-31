import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(SessionManager.self) private var sessionManager
    @Environment(\.modelContext) private var modelContext
    @Query private var connections: [ConnectionProfile]
    @State private var showAddConnection = false
    @State private var selectedConnection: ConnectionProfile?
    @State private var showSettings = false
    @State private var showTerminal = false
    @State private var quickConnectText = ""
    @State private var isRefreshing = false

    private var sortedConnections: [ConnectionProfile] {
        connections.sorted {
            ($0.lastConnectedAt ?? .distantPast) > ($1.lastConnectedAt ?? .distantPast)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                // Quick Connect
                Section {
                    HStack(spacing: 10) {
                        Image(systemName: "bolt.fill")
                            .foregroundStyle(.orange)
                            .font(.subheadline)
                        TextField("user@host or user@host:port", text: $quickConnectText)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.URL)
                            .submitLabel(.go)
                            .onSubmit { performQuickConnect() }
                        if !quickConnectText.isEmpty {
                            Button {
                                performQuickConnect()
                            } label: {
                                Image(systemName: "arrow.right.circle.fill")
                                    .foregroundStyle(.orange)
                                    .font(.title3)
                            }
                        }
                    }
                } header: {
                    Text("Quick Connect")
                }

                // Active Sessions
                if !sessionManager.sessions.isEmpty {
                    Section {
                        ForEach(sessionManager.sessions) { session in
                            Button {
                                sessionManager.activeSessionID = session.id
                                showTerminal = true
                            } label: {
                                Label {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(session.title)
                                            .foregroundStyle(.primary)
                                        Text(session.isConnected ? "Connected" : session.statusMessage)
                                            .font(.caption2)
                                            .foregroundStyle(session.isConnected ? .green : .secondary)
                                    }
                                } icon: {
                                    Image(systemName: session.isConnected ? "terminal.fill" : "terminal")
                                        .foregroundStyle(session.isConnected ? .green : .secondary)
                                }
                            }
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                sessionManager.closeSession(sessionManager.sessions[index].id)
                            }
                        }
                    } header: {
                        HStack {
                            Text("Active Sessions")
                            Spacer()
                            Text("\(sessionManager.sessions.count)")
                                .font(.caption2.bold())
                                .foregroundStyle(.white)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background(.green, in: Capsule())
                        }
                    }
                }

                // Saved Connections
                if sortedConnections.isEmpty {
                    Section("Connections") {
                        ContentUnavailableView {
                            Label("No Saved Connections", systemImage: "server.rack")
                        } description: {
                            Text("Add a connection with the + button, or use Quick Connect above.")
                        } actions: {
                            Button("Add Connection") {
                                showAddConnection = true
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                        }
                        .listRowBackground(Color.clear)
                    }
                } else {
                    Section("Connections (\(sortedConnections.count))") {
                        ForEach(sortedConnections) { connection in
                            Button {
                                connect(to: connection)
                            } label: {
                                ConnectionRow(profile: connection)
                            }
                            .contextMenu {
                                Button("Connect") {
                                    connect(to: connection)
                                }
                                Button("Edit") {
                                    selectedConnection = connection
                                    showAddConnection = true
                                }
                                Button("Delete", role: .destructive) {
                                    modelContext.delete(connection)
                                    try? modelContext.save()
                                }
                            }
                        }
                        .onDelete { indexSet in
                            let toDelete = indexSet.map { sortedConnections[$0] }
                            for item in toDelete {
                                modelContext.delete(item)
                            }
                            try? modelContext.save()
                        }
                    }
                }
            }
            .refreshable {
                // Pull-to-refresh: trigger a brief delay to let SwiftData sync
                try? await Task.sleep(for: .milliseconds(500))
            }
            .navigationTitle("mSSH")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showAddConnection = true }) {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .bottomBar) {
                    HStack {
                        Button(action: { showSettings = true }) {
                            Image(systemName: "gear")
                        }
                        Spacer()
                        if !sessionManager.sessions.isEmpty {
                            Button {
                                if let session = sessionManager.activeSession ?? sessionManager.sessions.first {
                                    sessionManager.activeSessionID = session.id
                                    showTerminal = true
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "terminal")
                                    Text("\(sessionManager.sessions.count)")
                                        .font(.caption.bold())
                                }
                            }
                        }
                        Spacer()
                        NavigationLink(destination: KeyManagerView()) {
                            Image(systemName: "key")
                        }
                    }
                }
            }
            .navigationDestination(isPresented: $showTerminal) {
                if let session = sessionManager.activeSession {
                    TerminalSessionView(session: session)
                }
            }
            .sheet(isPresented: $showAddConnection) {
                ConnectionFormView(existingProfile: selectedConnection)
                    .onDisappear { selectedConnection = nil }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
        }
    }

    private func connect(to profile: ConnectionProfile) {
        let session = sessionManager.createSession(for: profile)
        sessionManager.activeSessionID = session.id
        showTerminal = true
        Task {
            await session.connect()
        }
    }

    private func performQuickConnect() {
        let text = quickConnectText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }

        var username = "root"
        var host = text
        var port = 22

        // Parse user@host:port
        if let atIndex = text.firstIndex(of: "@") {
            username = String(text[text.startIndex..<atIndex])
            host = String(text[text.index(after: atIndex)...])
        }
        if let colonIndex = host.lastIndex(of: ":") {
            let portString = String(host[host.index(after: colonIndex)...])
            if let parsedPort = Int(portString), parsedPort > 0, parsedPort <= 65535 {
                port = parsedPort
                host = String(host[host.startIndex..<colonIndex])
            }
        }

        guard !host.isEmpty else { return }

        let label = "\(username)@\(host)"
        let profile = ConnectionProfile(
            label: label,
            host: host,
            port: port,
            username: username,
            authType: .password
        )
        modelContext.insert(profile)
        try? modelContext.save()

        quickConnectText = ""
        connect(to: profile)
    }
}

struct ConnectionRow: View {
    let profile: ConnectionProfile

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(profile.label)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text("\(profile.username)@\(profile.host):\(profile.port)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let lastConnected = profile.lastConnectedAt {
                Text(lastConnected, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
    }
}
