import SwiftUI

struct SessionTabView: View {
    @Environment(SessionManager.self) private var sessionManager

    var body: some View {
        @Bindable var manager = sessionManager
        VStack(spacing: 0) {
            // Tab bar
            if sessionManager.sessions.count > 1 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 0) {
                        ForEach(sessionManager.sessions) { session in
                            SessionTab(
                                title: session.title,
                                isActive: session.id == sessionManager.activeSessionID,
                                onTap: { sessionManager.activeSessionID = session.id },
                                onClose: { sessionManager.closeSession(session.id) }
                            )
                        }
                    }
                    .padding(.horizontal, 4)
                }
                .frame(height: 36)
                .background(Color(UIColor.secondarySystemBackground))
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
    let isActive: Bool
    let onTap: () -> Void
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.caption)
                .lineLimit(1)
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.caption2)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(isActive ? Color.accentColor.opacity(0.2) : Color.clear)
        .cornerRadius(6)
        .onTapGesture(perform: onTap)
    }
}
