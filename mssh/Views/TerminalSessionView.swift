import SwiftUI

struct TerminalSessionView: View {
    @Bindable var session: SessionViewModel

    var body: some View {
        ZStack {
            TerminalViewWrapper(bridge: session.bridge)
                .ignoresSafeArea(.keyboard)

            // Connection status overlay
            if !session.isConnected {
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
            ToolbarItem(placement: .primaryAction) {
                Button(action: { session.disconnect() }) {
                    Image(systemName: "xmark.circle")
                }
            }
        }
    }
}
