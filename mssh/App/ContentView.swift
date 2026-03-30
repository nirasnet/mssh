import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(SessionManager.self) private var sessionManager
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ConnectionProfile.lastConnectedAt, order: .reverse) private var connections: [ConnectionProfile]
    @State private var showAddConnection = false
    @State private var selectedConnection: ConnectionProfile?
    @State private var showSettings = false

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detail
        }
    }

    @ViewBuilder
    private var sidebar: some View {
        List(selection: $selectedConnection) {
            Section("Connections") {
                ForEach(connections) { connection in
                    ConnectionRow(profile: connection)
                        .tag(connection)
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
                            }
                        }
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        modelContext.delete(connections[index])
                    }
                }
            }

            if !sessionManager.sessions.isEmpty {
                Section("Active Sessions") {
                    ForEach(sessionManager.sessions) { session in
                        Label(session.title, systemImage: "terminal")
                            .onTapGesture {
                                sessionManager.activeSessionID = session.id
                            }
                    }
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
        .sheet(isPresented: $showAddConnection) {
            ConnectionFormView(existingProfile: selectedConnection)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
    }

    @ViewBuilder
    private var detail: some View {
        if sessionManager.sessions.isEmpty {
            VStack(spacing: 16) {
                Image(systemName: "terminal")
                    .font(.system(size: 64))
                    .foregroundStyle(.secondary)
                Text("No Active Sessions")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                if let first = connections.first {
                    Button("Connect to \(first.label)") {
                        connect(to: first)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        } else {
            SessionTabView()
        }
    }

    private func connect(to profile: ConnectionProfile) {
        let session = sessionManager.createSession(for: profile)
        sessionManager.activeSessionID = session.id
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
            Text("\(profile.username)@\(profile.host):\(profile.port)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}
