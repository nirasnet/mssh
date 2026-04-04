import SwiftUI

struct SessionTabView: View {
    @Environment(SessionManager.self) private var sessionManager

    var body: some View {
        @Bindable var manager = sessionManager
        VStack(spacing: 0) {
            // Tab bar - only shown for multiple sessions
            if sessionManager.sessions.count > 1 {
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 3) {
                            ForEach(sessionManager.sessions) { session in
                                SessionTab(
                                    title: session.title,
                                    isConnected: session.isConnected,
                                    isActive: session.id == sessionManager.activeSessionID,
                                    onTap: {
                                        withAnimation(.easeInOut(duration: 0.15)) {
                                            sessionManager.activeSessionID = session.id
                                        }
                                    },
                                    onClose: { sessionManager.closeSession(session.id) }
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
                        Rectangle()
                            .frame(height: 0.5)
                            .foregroundStyle(AppColors.border),
                        alignment: .bottom
                    )
                    .onChange(of: sessionManager.activeSessionID) { _, newID in
                        if let newID {
                            withAnimation {
                                proxy.scrollTo(newID, anchor: .center)
                            }
                        }
                    }
                }
            }

            // Active terminal
            if let session = sessionManager.activeSession {
                TerminalSessionView(session: session)
            }
        }
    }
}

struct SessionTab: View {
    let title: String
    let isConnected: Bool
    let isActive: Bool
    let onTap: () -> Void
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: 5) {
            StatusDot(isConnected: isConnected)

            Text(title)
                .font(.system(size: 11, weight: isActive ? .semibold : .regular, design: .monospaced))
                .foregroundStyle(isActive ? AppColors.textPrimary : AppColors.textSecondary)
                .lineLimit(1)

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(isActive ? AppColors.textSecondary : AppColors.textTertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(isActive ? AppColors.accentDim : AppColors.surfaceElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(isActive ? AppColors.accent.opacity(0.3) : AppColors.border, lineWidth: 0.5)
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }
}
