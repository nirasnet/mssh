import SwiftUI

// MARK: - Split Session Tab View

struct SplitSessionTabView: View {
    @Environment(SessionManager.self) private var sessionManager
    @Environment(\.modelContext) private var modelContext
    @State private var splitSession: SessionViewModel?
    @State private var splitDirection: SplitDirection = .leftRight
    @State private var focusedPane: Pane = .primary

    enum SplitDirection {
        case leftRight   // side by side
        case topBottom   // stacked
    }

    enum Pane {
        case primary
        case secondary
    }

    private var isSplit: Bool { splitSession != nil }

    var body: some View {
        VStack(spacing: 0) {
            // Tab bar
            if sessionManager.sessions.count > 1 {
                sessionTabBar
            }

            // Terminal content
            if let activeSession = sessionManager.activeSession {
                terminalContent(activeSession)
            } else {
                emptyState
            }
        }
        .background(AppColors.terminalBg)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                toolbarButtons
            }
        }
        .onAppear { injectModelContainer() }
    }

    // MARK: - Terminal Content

    @ViewBuilder
    private func terminalContent(_ session: SessionViewModel) -> some View {
        if let splitSession, isSplit {
            // Split view
            switch splitDirection {
            case .leftRight:
                HStack(spacing: 0) {
                    terminalPane(session: session, pane: .primary)
                    Rectangle().fill(AppColors.accent.opacity(0.3)).frame(width: 2)
                    terminalPane(session: splitSession, pane: .secondary)
                }
            case .topBottom:
                VStack(spacing: 0) {
                    terminalPane(session: session, pane: .primary)
                    Rectangle().fill(AppColors.accent.opacity(0.3)).frame(height: 2)
                    terminalPane(session: splitSession, pane: .secondary)
                }
            }
        } else {
            // Single pane
            singlePane(session: session)
        }
    }

    private func terminalPane(session: SessionViewModel, pane: Pane) -> some View {
        ZStack {
            AppColors.terminalBg
            TerminalViewWrapper(bridge: session.bridge)

            // Focus border
            if focusedPane == pane {
                RoundedRectangle(cornerRadius: 0)
                    .strokeBorder(AppColors.accent, lineWidth: 2)
                    .allowsHitTesting(false)
            }

            // Disconnected overlay
            if !session.isConnected && !session.statusMessage.contains("Connecting") {
                VStack(spacing: AppSpacing.sm) {
                    Image(systemName: "bolt.slash.fill")
                        .font(.title2)
                        .foregroundStyle(AppColors.textTertiary)
                    Text(session.statusMessage)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(AppSpacing.md)
                .background(AppColors.background.opacity(0.85))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { focusedPane = pane }
    }

    private func singlePane(session: SessionViewModel) -> some View {
        ZStack {
            AppColors.terminalBg
            TerminalViewWrapper(bridge: session.bridge)
                .ignoresSafeArea(.container, edges: .bottom)

            // Host key prompt
            if let promptType = session.pendingHostKeyPrompt {
                Color.black.opacity(0.6).ignoresSafeArea()
                HostKeyPromptView(
                    promptType: promptType,
                    onAccept: { session.acceptHostKey() },
                    onReject: { session.rejectHostKey() }
                )
            }

            // Error overlay
            if session.statusMessage.starts(with: "Connection failed") ||
               session.statusMessage.starts(with: "Error:") ||
               session.statusMessage.starts(with: "SSH key not found") {
                VStack {
                    Spacer()
                    HStack(spacing: AppSpacing.sm) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(AppColors.warning)
                        Text(session.statusMessage)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(AppColors.textPrimary)
                    }
                    .padding(AppSpacing.md)
                    .background(AppColors.surface.opacity(0.95))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .padding(.bottom, AppSpacing.xxl)
                }
            }
        }
    }

    // MARK: - Toolbar

    @ViewBuilder
    private var toolbarButtons: some View {
        if sessionManager.activeSession != nil {
            // Split controls
            Menu {
                Button {
                    performSplit(.leftRight)
                } label: {
                    Label("Split Left / Right", systemImage: "rectangle.split.2x1")
                }
                Button {
                    performSplit(.topBottom)
                } label: {
                    Label("Split Top / Bottom", systemImage: "rectangle.split.1x2")
                }
                if isSplit {
                    Divider()
                    Button {
                        closeSplit()
                    } label: {
                        Label("Close Split", systemImage: "xmark.rectangle")
                    }
                }
            } label: {
                Image(systemName: isSplit ? "rectangle.split.2x1.fill" : "rectangle.split.2x1")
                    .font(.system(size: 14))
            }

            // Claude Code
            Menu {
                Button {
                    sendClaudeCommand()
                } label: {
                    Label("Run claude in terminal", systemImage: "sparkle")
                }
                Divider()
                Button {
                    performSplit(.leftRight)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        sendClaudeCommandToSplit()
                    }
                } label: {
                    Label("Claude Code — Split Right", systemImage: "rectangle.righthalf.inset.filled")
                }
                Button {
                    performSplit(.topBottom)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        sendClaudeCommandToSplit()
                    }
                } label: {
                    Label("Claude Code — Split Bottom", systemImage: "rectangle.bottomhalf.inset.filled")
                }
            } label: {
                Image(systemName: "sparkle")
                    .font(.system(size: 14))
            }

            // Close session
            Button {
                if let id = sessionManager.activeSessionID {
                    closeSplit()
                    sessionManager.closeSession(id)
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppColors.textSecondary)
            }
        }
    }

    // MARK: - Session Tab Bar

    private var sessionTabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 3) {
                ForEach(sessionManager.sessions.filter({ s in
                    // Don't show split sessions as separate tabs
                    s.id != splitSession?.id
                })) { session in
                    SessionTab(
                        title: session.title,
                        isConnected: session.isConnected,
                        isActive: session.id == sessionManager.activeSessionID,
                        onTap: {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                closeSplit()
                                sessionManager.activeSessionID = session.id
                            }
                        },
                        onClose: {
                            closeSplit()
                            sessionManager.closeSession(session.id)
                        }
                    )
                    .id(session.id)
                }
            }
            .padding(.horizontal, AppSpacing.sm)
            .padding(.vertical, AppSpacing.xs)
        }
        .frame(height: 38)
        .background(AppColors.surface)
        .overlay(
            Rectangle().frame(height: 0.5).foregroundStyle(AppColors.border),
            alignment: .bottom
        )
    }

    private var emptyState: some View {
        VStack(spacing: AppSpacing.lg) {
            Image(systemName: "terminal")
                .font(.system(size: 40))
                .foregroundStyle(AppColors.textTertiary)
            Text("No Active Sessions")
                .font(AppFonts.subheading)
                .foregroundStyle(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Actions

    private func injectModelContainer() {
        for session in sessionManager.sessions {
            if session.modelContainer == nil {
                session.modelContainer = modelContext.container
            }
        }
    }

    private func performSplit(_ direction: SplitDirection) {
        guard let activeSession = sessionManager.activeSession else { return }

        // Close existing split first
        if let existing = splitSession {
            sessionManager.closeSession(existing.id)
            splitSession = nil
        }

        // Create new session for the split pane
        let newSession = SessionViewModel(profile: activeSession.profile)
        newSession.modelContainer = modelContext.container
        sessionManager.sessions.append(newSession)
        // Don't change activeSessionID

        splitDirection = direction
        splitSession = newSession
        focusedPane = .secondary

        Task { await newSession.connect() }
    }

    private func closeSplit() {
        if let session = splitSession {
            sessionManager.closeSession(session.id)
            splitSession = nil
            focusedPane = .primary
        }
    }

    private func sendClaudeCommand() {
        guard let session = sessionManager.activeSession, session.isConnected else { return }
        let bytes = Array("claude\n".utf8)
        session.bridge.sendToSSH(data: ArraySlice(bytes))
    }

    private func sendClaudeCommandToSplit() {
        guard let session = splitSession, session.isConnected else { return }
        let bytes = Array("claude\n".utf8)
        session.bridge.sendToSSH(data: ArraySlice(bytes))
    }
}
