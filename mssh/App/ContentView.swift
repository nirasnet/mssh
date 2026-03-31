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

    private var sortedConnections: [ConnectionProfile] {
        connections.sorted {
            ($0.lastConnectedAt ?? .distantPast) > ($1.lastConnectedAt ?? .distantPast)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                // Active Sessions
                if !sessionManager.sessions.isEmpty {
                    Section("Active Sessions") {
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
                    }
                }

                // Saved Connections
                Section("Connections") {
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
}

struct ConnectionRow: View {
    let profile: ConnectionProfile

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(profile.label)
                .font(.headline)
                .foregroundStyle(.primary)
            Text("\(profile.username)@\(profile.host):\(profile.port)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}
