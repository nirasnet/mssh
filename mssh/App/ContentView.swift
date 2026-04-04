import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(SessionManager.self) private var sessionManager
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var selectedTab: AppTab = .connections

    enum AppTab: Hashable {
        case connections
        case terminal
        case keys
        case settings
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Connections", systemImage: "server.rack", value: .connections) {
                if sizeClass == .regular {
                    iPadConnectionsView(selectedTab: $selectedTab)
                } else {
                    iPhoneConnectionsView(selectedTab: $selectedTab)
                }
            }

            Tab("Terminal", systemImage: "terminal.fill", value: .terminal) {
                TerminalTabContent()
            }
            .badge(sessionManager.sessions.count)

            Tab("Keys", systemImage: "key.fill", value: .keys) {
                NavigationStack {
                    KeyManagerView()
                        .navigationTitle("SSH Keys")
                }
            }

            Tab("Settings", systemImage: "gear", value: .settings) {
                NavigationStack {
                    SettingsView()
                }
            }
        }
        .tint(AppColors.accent)
        .appTheme()
    }
}

// MARK: - Terminal Tab Content

private struct TerminalTabContent: View {
    @Environment(SessionManager.self) private var sessionManager

    var body: some View {
        if sessionManager.sessions.isEmpty {
            NavigationStack {
                VStack(spacing: AppSpacing.lg) {
                    Image(systemName: "terminal")
                        .font(.system(size: 40))
                        .foregroundStyle(AppColors.textTertiary)
                    Text("No Active Sessions")
                        .font(AppFonts.subheading)
                        .foregroundStyle(AppColors.textSecondary)
                    Text("Connect to a server from the Connections tab")
                        .font(.caption)
                        .foregroundStyle(AppColors.textTertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(AppColors.background)
                .navigationTitle("Terminal")
            }
        } else {
            NavigationStack {
                SplitSessionTabView()
                    .navigationTitle("Terminal")
                    .iOSOnlyNavigationBarTitleDisplayMode()
            }
        }
    }
}

// MARK: - iPhone Connections View

private struct iPhoneConnectionsView: View {
    @Environment(SessionManager.self) private var sessionManager
    @Environment(\.modelContext) private var modelContext
    @Query private var connections: [ConnectionProfile]
    @State private var showAddConnection = false
    @State private var selectedConnection: ConnectionProfile?
    @State private var quickConnectText = ""
    @State private var showClearAlert = false
    @State private var showImportConfig = false
    @Binding var selectedTab: ContentView.AppTab

    private var sortedConnections: [ConnectionProfile] {
        connections.sorted {
            ($0.lastConnectedAt ?? .distantPast) > ($1.lastConnectedAt ?? .distantPast)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    quickConnectBar
                    activeSessions
                    savedConnections
                }
            }
            .background(AppColors.background)
            .scrollContentBackground(.hidden)
            .navigationTitle("mSSH")
            #if os(iOS)
            .toolbarColorScheme(.dark, for: .navigationBar)
            #endif
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    HStack(spacing: AppSpacing.sm) {
                        if !sortedConnections.isEmpty {
                            Button(role: .destructive, action: { showClearAlert = true }) {
                                Image(systemName: "trash")
                                    .font(.system(size: 14))
                            }
                        }
                        Menu {
                            Button {
                                showAddConnection = true
                            } label: {
                                Label("New Connection", systemImage: "plus")
                            }
                            Button {
                                showImportConfig = true
                            } label: {
                                Label("Import SSH Config", systemImage: "doc.text")
                            }
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .symbolRenderingMode(.hierarchical)
                                .font(.title3)
                        }
                    }
                }
            }
            .alert("Clear All Connections?", isPresented: $showClearAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Clear All", role: .destructive) {
                    for conn in connections {
                        modelContext.delete(conn)
                    }
                    try? modelContext.save()
                }
            } message: {
                Text("This will delete all \(connections.count) saved connections. This cannot be undone.")
            }
            .sheet(isPresented: $showAddConnection) {
                ConnectionFormView(existingProfile: selectedConnection)
                    .onDisappear { selectedConnection = nil }
            }
            .sheet(isPresented: $showImportConfig) {
                SSHConfigImportView()
            }
        }
    }

    // MARK: - Quick Connect Bar

    private var quickConnectBar: some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 13))
                .foregroundStyle(AppColors.accent)

            TextField("user@host:port", text: $quickConnectText)
                .font(.system(.body, design: .monospaced))
                .iOSOnlyTextInputAutocapitalization()
                .autocorrectionDisabled()
                #if os(iOS)
                .keyboardType(.URL)
                #endif
                .submitLabel(.go)
                .onSubmit { performQuickConnect() }
                .foregroundStyle(AppColors.textPrimary)

            if !quickConnectText.isEmpty {
                Button(action: performQuickConnect) {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.title3)
                        .foregroundStyle(AppColors.accent)
                }
            }
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.md)
        .background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(AppColors.border, lineWidth: 0.5)
        )
        .padding(.horizontal, AppSpacing.lg)
        .padding(.top, AppSpacing.sm)
    }

    // MARK: - Active Sessions

    @ViewBuilder
    private var activeSessions: some View {
        if !sessionManager.sessions.isEmpty {
            VStack(spacing: 0) {
                AppSectionHeader(title: "Active Sessions", count: sessionManager.sessions.count)

                VStack(spacing: AppSpacing.sm) {
                    ForEach(sessionManager.sessions) { session in
                        Button {
                            sessionManager.activeSessionID = session.id
                            selectedTab = .terminal
                        } label: {
                            HStack(spacing: AppSpacing.md) {
                                StatusDot(isConnected: session.isConnected)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(session.title)
                                        .font(.system(.subheadline, design: .monospaced).weight(.medium))
                                        .foregroundStyle(AppColors.textPrimary)
                                    Text(session.isConnected ? "Connected" : session.statusMessage)
                                        .font(AppFonts.monoCaption)
                                        .foregroundStyle(session.isConnected ? AppColors.connected : AppColors.textSecondary)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(AppColors.textTertiary)
                            }
                            .appCard(isActive: session.isConnected)
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                sessionManager.closeSession(session.id)
                            } label: {
                                Label("Close", systemImage: "xmark.circle")
                            }
                        }
                    }
                }
                .padding(.horizontal, AppSpacing.lg)
            }
        }
    }

    // MARK: - Saved Connections

    private var savedConnections: some View {
        VStack(spacing: 0) {
            AppSectionHeader(title: "Connections", count: sortedConnections.isEmpty ? nil : sortedConnections.count)

            if sortedConnections.isEmpty {
                emptyState
            } else {
                VStack(spacing: AppSpacing.sm) {
                    ForEach(sortedConnections) { connection in
                        Button {
                            connect(to: connection)
                        } label: {
                            ConnectionRow(profile: connection)
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                modelContext.delete(connection)
                                try? modelContext.save()
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .swipeActions(edge: .leading) {
                            Button {
                                selectedConnection = connection
                                showAddConnection = true
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            .tint(AppColors.accent)
                        }
                        .contextMenu {
                            Button {
                                connect(to: connection)
                            } label: {
                                Label("Connect", systemImage: "bolt.fill")
                            }
                            Button {
                                selectedConnection = connection
                                showAddConnection = true
                            } label: {
                                Label("Edit", systemImage: "pencil")
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
                .padding(.horizontal, AppSpacing.lg)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: AppSpacing.md) {
            Image(systemName: "server.rack")
                .font(.system(size: 32))
                .foregroundStyle(AppColors.textTertiary)

            Text("No Saved Connections")
                .font(AppFonts.subheading)
                .foregroundStyle(AppColors.textSecondary)

            Text("Add a connection or use Quick Connect")
                .font(.caption)
                .foregroundStyle(AppColors.textTertiary)

            Button {
                showAddConnection = true
            } label: {
                Text("Add Connection")
                    .font(AppFonts.label)
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.vertical, AppSpacing.sm)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.xxl)
    }

    // MARK: - Actions

    private func connect(to profile: ConnectionProfile) {
        let session = sessionManager.createSession(for: profile)
        session.modelContainer = modelContext.container
        sessionManager.activeSessionID = session.id
        selectedTab = .terminal
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

// MARK: - iPad Connections View (Split View)

private struct iPadConnectionsView: View {
    @Environment(SessionManager.self) private var sessionManager
    @Environment(\.modelContext) private var modelContext
    @Query private var connections: [ConnectionProfile]
    @State private var showAddConnection = false
    @State private var selectedConnection: ConnectionProfile?
    @State private var quickConnectText = ""
    @State private var selectedProfile: ConnectionProfile?
    @State private var showClearAlert = false
    @State private var showImportConfig = false
    @Binding var selectedTab: ContentView.AppTab

    private var sortedConnections: [ConnectionProfile] {
        connections.sorted {
            ($0.lastConnectedAt ?? .distantPast) > ($1.lastConnectedAt ?? .distantPast)
        }
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedProfile) {
                // Quick connect
                Section {
                    HStack(spacing: AppSpacing.sm) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(AppColors.accent)
                        TextField("user@host:port", text: $quickConnectText)
                            .font(.system(.body, design: .monospaced))
                            .iOSOnlyTextInputAutocapitalization()
                            .autocorrectionDisabled()
                            #if os(iOS)
                            .keyboardType(.URL)
                            #endif
                            .submitLabel(.go)
                            .onSubmit { performQuickConnect() }
                    }
                    .listRowBackground(AppColors.surface)
                }

                // Active sessions
                if !sessionManager.sessions.isEmpty {
                    Section("Active Sessions") {
                        ForEach(sessionManager.sessions) { session in
                            Button {
                                sessionManager.activeSessionID = session.id
                                selectedTab = .terminal
                            } label: {
                                HStack(spacing: AppSpacing.sm) {
                                    StatusDot(isConnected: session.isConnected)
                                    Text(session.title)
                                        .font(.system(.subheadline, design: .monospaced))
                                        .foregroundStyle(AppColors.textPrimary)
                                    Spacer()
                                    Text(session.isConnected ? "Connected" : "...")
                                        .font(.caption2)
                                        .foregroundStyle(session.isConnected ? AppColors.connected : AppColors.textTertiary)
                                }
                            }
                            .listRowBackground(AppColors.surface)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    sessionManager.closeSession(session.id)
                                } label: {
                                    Label("Close", systemImage: "xmark.circle")
                                }
                            }
                        }
                    }
                }

                // Saved connections
                Section("Connections") {
                    ForEach(sortedConnections) { connection in
                        Button {
                            connect(to: connection)
                        } label: {
                            HStack(spacing: AppSpacing.md) {
                                Image(systemName: "server.rack")
                                    .font(.system(size: 14))
                                    .foregroundStyle(AppColors.accent)
                                    .frame(width: 24)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(connection.label)
                                        .font(.system(.subheadline, design: .monospaced).weight(.medium))
                                        .foregroundStyle(AppColors.textPrimary)
                                    Text("\(connection.username)@\(connection.host):\(connection.port)")
                                        .font(AppFonts.monoCaption)
                                        .foregroundStyle(AppColors.textSecondary)
                                }

                                Spacer()

                                Image(systemName: connection.authType == .key ? "key.fill" : "lock.fill")
                                    .font(.system(size: 10))
                                    .foregroundStyle(AppColors.textTertiary)
                            }
                        }
                        .listRowBackground(AppColors.surface)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                modelContext.delete(connection)
                                try? modelContext.save()
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .swipeActions(edge: .leading) {
                            Button {
                                selectedConnection = connection
                                showAddConnection = true
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            .tint(AppColors.accent)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppColors.background)
            .navigationTitle("mSSH")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    HStack(spacing: AppSpacing.sm) {
                        if !sortedConnections.isEmpty {
                            Button(role: .destructive, action: { showClearAlert = true }) {
                                Image(systemName: "trash")
                                    .font(.system(size: 14))
                            }
                        }
                        Menu {
                            Button {
                                showAddConnection = true
                            } label: {
                                Label("New Connection", systemImage: "plus")
                            }
                            Button {
                                showImportConfig = true
                            } label: {
                                Label("Import SSH Config", systemImage: "doc.text")
                            }
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .symbolRenderingMode(.hierarchical)
                                .font(.title3)
                        }
                    }
                }
            }
            .alert("Clear All Connections?", isPresented: $showClearAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Clear All", role: .destructive) {
                    for conn in connections {
                        modelContext.delete(conn)
                    }
                    try? modelContext.save()
                }
            } message: {
                Text("This will delete all \(connections.count) saved connections. This cannot be undone.")
            }
            .sheet(isPresented: $showAddConnection) {
                ConnectionFormView(existingProfile: selectedConnection)
                    .onDisappear { selectedConnection = nil }
            }
            .sheet(isPresented: $showImportConfig) {
                SSHConfigImportView()
            }
        } detail: {
            // Detail pane: show welcome or active terminal
            VStack(spacing: AppSpacing.lg) {
                Image(systemName: "terminal")
                    .font(.system(size: 48))
                    .foregroundStyle(AppColors.textTertiary)
                Text("Select a connection to get started")
                    .font(AppFonts.subheading)
                    .foregroundStyle(AppColors.textSecondary)
                Text("Or use Quick Connect in the sidebar")
                    .font(.caption)
                    .foregroundStyle(AppColors.textTertiary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppColors.background)
        }
        .tint(AppColors.accent)
    }

    private func connect(to profile: ConnectionProfile) {
        let session = sessionManager.createSession(for: profile)
        session.modelContainer = modelContext.container
        sessionManager.activeSessionID = session.id
        selectedTab = .terminal
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

// MARK: - Connection Row

struct ConnectionRow: View {
    let profile: ConnectionProfile

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            // Server icon
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(AppColors.accentDim)
                    .frame(width: 36, height: 36)
                Image(systemName: "server.rack")
                    .font(.system(size: 14))
                    .foregroundStyle(AppColors.accent)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(profile.label)
                    .font(.system(.subheadline, design: .monospaced).weight(.medium))
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(1)

                Text("\(profile.username)@\(profile.host):\(profile.port)")
                    .font(AppFonts.monoCaption)
                    .foregroundStyle(AppColors.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                if let lastConnected = profile.lastConnectedAt {
                    Text(lastConnected, style: .relative)
                        .font(.system(size: 10))
                        .foregroundStyle(AppColors.textTertiary)
                }
                HStack(spacing: 4) {
                    Image(systemName: profile.authType == .key ? "key.fill" : "lock.fill")
                        .font(.system(size: 9))
                    Text(profile.authType == .key ? "Key" : "Pass")
                        .font(.system(size: 9, weight: .medium))
                }
                .foregroundStyle(AppColors.textTertiary)
            }
        }
        .appCard()
    }
}
