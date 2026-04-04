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
            // Terminal fills entire area
            AppColors.terminalBg
                .ignoresSafeArea()

            TerminalViewWrapper(bridge: session.bridge)
                .ignoresSafeArea(.container, edges: .bottom)

            // Connection error overlay
            if session.statusMessage.starts(with: "Connection failed") ||
               session.statusMessage.starts(with: "Error:") {
                VStack {
                    Spacer()
                    errorBanner
                        .padding(.horizontal, AppSpacing.lg)
                        .padding(.bottom, AppSpacing.xxl)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // Host key verification prompt
            if let promptType = session.pendingHostKeyPrompt {
                Color.black.opacity(0.6)
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
            if !session.isConnected && session.statusMessage != "Connecting..." {
                Task { await session.connect() }
            }
        }
        .iOSOnlyNavigationBarTitleDisplayMode()
        #if os(iOS)
        .toolbarBackground(AppColors.surface, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        #endif
        .toolbar {
            ToolbarItem(placement: .principal) {
                Button {
                    showConnectionInfo = true
                } label: {
                    HStack(spacing: AppSpacing.sm) {
                        StatusDot(isConnected: session.isConnected)
                        Text(session.title)
                            .font(.system(.caption, design: .monospaced).weight(.semibold))
                            .foregroundStyle(AppColors.textPrimary)
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
                HStack(spacing: AppSpacing.xs) {
                    Button {
                        pasteFromClipboard()
                    } label: {
                        Image(systemName: "doc.on.clipboard")
                            .font(.system(size: 14))
                    }
                    .disabled(!session.isConnected)

                    Button {
                        showSFTPBrowser = true
                    } label: {
                        Image(systemName: "folder")
                            .font(.system(size: 14))
                    }
                    .disabled(!session.isConnected || session.sshClient == nil)

                    Button {
                        sessionManager.closeSession(session.id)
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }
            }
        }
        .sheet(isPresented: $showSFTPBrowser) {
            if let client = session.sshClient {
                SFTPBrowserView(client: client)
            }
        }
        .appTheme()
    }

    // MARK: - Error Banner

    private var errorBanner: some View {
        VStack(spacing: AppSpacing.md) {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(AppColors.warning)
                    .font(.callout)
                Text(session.statusMessage)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(AppColors.textPrimary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)
            }

            Button {
                Task { await session.connect() }
            } label: {
                Text("Retry")
                    .font(AppFonts.label)
                    .foregroundStyle(AppColors.accent)
                    .padding(.horizontal, AppSpacing.xl)
                    .padding(.vertical, AppSpacing.sm)
                    .background(AppColors.accentDim)
                    .clipShape(Capsule())
            }
        }
        .padding(AppSpacing.lg)
        .background(AppColors.surface.opacity(0.95))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(AppColors.error.opacity(0.3), lineWidth: 0.5)
        )
    }

    private func pasteFromClipboard() {
        guard let text = AppClipboard.paste(), !text.isEmpty else { return }
        let bytes = Array(text.utf8)
        session.bridge.sendToSSH(data: ArraySlice(bytes))
    }
}

// MARK: - Connection Info Popover

struct ConnectionInfoPopover: View {
    let session: SessionViewModel
    let connectedSince: Date

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            HStack {
                Text("Connection")
                    .font(AppFonts.subheading)
                    .foregroundStyle(AppColors.textPrimary)
                Spacer()
                StatusDot(isConnected: session.isConnected)
            }

            VStack(spacing: AppSpacing.sm) {
                infoRow("person.fill", "User", session.profile.username)
                infoRow("server.rack", "Host", session.profile.host)
                infoRow("number", "Port", "\(session.profile.port)")
                infoRow(
                    session.isConnected ? "checkmark.circle.fill" : "xmark.circle",
                    "Status",
                    session.isConnected ? "Connected" : session.statusMessage,
                    color: session.isConnected ? AppColors.connected : AppColors.error
                )
                if session.isConnected {
                    infoRow("clock", "Uptime", uptimeString)
                }
                infoRow(
                    "lock.fill", "Auth",
                    session.profile.authType == .password ? "Password" : "SSH Key"
                )
            }
        }
        .padding(AppSpacing.lg)
        .frame(minWidth: 260)
        .background(AppColors.surface)
    }

    private func infoRow(_ icon: String, _ label: String, _ value: String, color: Color = AppColors.textPrimary) -> some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(AppColors.textTertiary)
                .frame(width: 18)
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(AppColors.textSecondary)
                .frame(width: 48, alignment: .leading)
            Text(value)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(color)
                .lineLimit(1)
        }
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
