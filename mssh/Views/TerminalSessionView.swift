import SwiftUI

struct TerminalSessionView: View {
    @Bindable var session: SessionViewModel
    @Environment(\.modelContext) private var modelContext
    @State private var showSFTPBrowser = false

    var body: some View {
        ZStack {
            TerminalViewWrapper(bridge: session.bridge)
                .ignoresSafeArea(.keyboard)

            // Connection status overlay
            if !session.isConnected && session.pendingHostKeyPrompt == nil {
                VStack(spacing: 12) {
                    ProgressView()
                    Text(session.statusMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("Reconnect") {
                        Task { await session.connect() }
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
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
        .onAppear {
            session.modelContainer = modelContext.container
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 1) {
                    Text(session.title)
                        .font(.caption.bold())
                    Text(session.statusMessage)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    showSFTPBrowser = true
                } label: {
                    Image(systemName: "folder.fill")
                }
                .disabled(!session.isConnected || session.sshClient == nil)

                Button(action: { session.disconnect() }) {
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
}
