import SwiftUI

struct TerminalSessionView: View {
    @Bindable var session: SessionViewModel
    @Environment(SessionManager.self) private var sessionManager
    @Environment(\.modelContext) private var modelContext
    @State private var showSFTPBrowser = false

    var body: some View {
        ZStack {
            TerminalViewWrapper(bridge: session.bridge)

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
}
