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
                        HStack(spacing: 2) {
                            ForEach(sessionManager.sessions) { session in
                                SessionTab(
                                    title: session.title,
                                    isConnected: session.isConnected,
                                    isActive: session.id == sessionManager.activeSessionID,
                                    onTap: {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            sessionManager.activeSessionID = session.id
                                        }
                                    },
                                    onClose: { sessionManager.closeSession(session.id) }
                                )
                                .id(session.id)
                            }
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                    }
                    .frame(height: 40)
                    .background(Color(UIColor.secondarySystemBackground))
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
        HStack(spacing: 6) {
            Circle()
                .fill(isConnected ? Color.green : Color.secondary.opacity(0.5))
                .frame(width: 6, height: 6)
            Text(title)
                .font(.caption)
                .fontWeight(isActive ? .semibold : .regular)
                .lineLimit(1)
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(isActive ? .primary : .secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isActive ? Color.accentColor.opacity(0.2) : Color(UIColor.tertiarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(isActive ? Color.accentColor.opacity(0.4) : Color.clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }
}
