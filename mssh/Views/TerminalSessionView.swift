import SwiftUI

struct TerminalSessionView: View {
    @Bindable var session: SessionViewModel
    @Environment(SessionManager.self) private var sessionManager
    @Environment(\.modelContext) private var modelContext
    @State private var showSFTPBrowser = false
    @State private var showConnectionInfo = false
    @State private var connectionStartTime = Date()

    var body: some View {
        ZStack {
            TerminalViewWrapper(bridge: session.bridge)
                .ignoresSafeArea(.container, edges: .bottom)

            // Connection error overlay
            if session.statusMessage.starts(with: "Connection failed") ||
               session.statusMessage.starts(with: "Error:") {
                VStack(spacing: 12) {
                    Spacer()
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.yellow)
                        Text(session.statusMessage)
                            .font(.callout)
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .background(.red.opacity(0.85), in: RoundedRectangle(cornerRadius: 10))
                    .padding(.horizontal)

                    Button("Retry") {
                        Task { await session.connect() }
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.bottom, 40)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // Host key verification prompt
            if let promptType = session.pendingHostKeyPrompt {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()

                HostKeyPromptView(
                    promptType: promptType,
                    onAccept: { session.acceptHostKey() },
                    onReject: { session.rejectHostKey() }
                )
                .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: session.statusMessage)
        .onAppear {
            session.modelContainer = modelContext.container
            connectionStartTime = Date()
            // If not yet connected (e.g. model container wasn't set when
            // connect() was first called), start the connection now.
            if !session.isConnected && session.statusMessage != "Connecting..." {
                Task { await session.connect() }
            }
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Button {
                    showConnectionInfo = true
                } label: {
                    VStack(spacing: 1) {
                        Text(session.title)
                            .font(.caption.bold())
                            .foregroundStyle(.primary)
                        Text(session.statusMessage)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .popover(isPresented: $showConnectionInfo) {
                    ConnectionInfoPopover(
                        session: session,
                        connectedSince: connectionStartTime
                    )
                    .presentationCompactAdaptation(.popover)
                }
            }
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    pasteFromClipboard()
                } label: {
                    Image(systemName: "doc.on.clipboard")
                }
                .disabled(!session.isConnected)

                Button {
                    showSFTPBrowser = true
                } label: {
                    Image(systemName: "folder.fill")
                }
                .disabled(!session.isConnected || session.sshClient == nil)

                Button {
                    sessionManager.closeSession(session.id)
                } label: {
                    Image(systemName: "xmark.circle")
                }
            }
        }
        .sheet(isPresented: $showSFTPBrowser) {
            if let client = session.sshClient {
                SFTPBrowserView(client: client)
            }
        }
    }

    private func pasteFromClipboard() {
        guard let text = UIPasteboard.general.string, !text.isEmpty else { return }
        let bytes = Array(text.utf8)
        session.bridge.sendToSSH(data: ArraySlice(bytes))
    }
}

struct ConnectionInfoPopover: View {
    let session: SessionViewModel
    let connectedSince: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Connection Info")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                ConnectionInfoRow(icon: "person.fill", label: "User", value: session.profile.username)
                ConnectionInfoRow(icon: "server.rack", label: "Host", value: session.profile.host)
                ConnectionInfoRow(icon: "number", label: "Port", value: "\(session.profile.port)")
                ConnectionInfoRow(
                    icon: session.isConnected ? "circle.fill" : "circle",
                    label: "Status",
                    value: session.isConnected ? "Connected" : session.statusMessage,
                    valueColor: session.isConnected ? .green : .red
                )
                if session.isConnected {
                    ConnectionInfoRow(
                        icon: "clock",
                        label: "Uptime",
                        value: uptimeString
                    )
                }
                ConnectionInfoRow(
                    icon: "lock.fill",
                    label: "Auth",
                    value: session.profile.authType == .password ? "Password" : "SSH Key"
                )
            }
        }
        .padding()
        .frame(minWidth: 250)
    }

    private var uptimeString: String {
        let interval = Date().timeIntervalSince(connectedSince)
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        let seconds = Int(interval) % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m \(seconds)s"
        } else if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(seconds)s"
        }
    }
}

private struct ConnectionInfoRow: View {
    let icon: String
    let label: String
    let value: String
    var valueColor: Color = .primary

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 20)
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 50, alignment: .leading)
            Text(value)
                .font(.subheadline.monospaced())
                .foregroundStyle(valueColor)
        }
    }
}
