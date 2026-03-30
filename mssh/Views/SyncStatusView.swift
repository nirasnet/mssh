import SwiftUI

/// A compact sync status indicator suitable for placement in a sidebar header or toolbar.
struct SyncStatusView: View {
    @Environment(iCloudSyncService.self) private var syncService

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: syncService.status.systemImage)
                .font(.footnote)
                .foregroundStyle(iconColor)
                .symbolEffect(.pulse, isActive: syncService.status == .syncing)

            if showLabel {
                Text(syncService.status.label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .help(helpText)
        .accessibilityLabel(syncService.status.label)
    }

    private var showLabel: Bool {
        switch syncService.status {
        case .syncing, .error:
            return true
        default:
            return false
        }
    }

    private var iconColor: Color {
        switch syncService.status {
        case .synced:
            return .green
        case .syncing:
            return .blue
        case .error:
            return .red
        case .notAvailable:
            return .secondary
        case .notStarted:
            return .secondary
        }
    }

    private var helpText: String {
        var text = syncService.status.label
        if let date = syncService.lastSyncDate {
            text += "\nLast synced: \(date.formatted(.relative(presentation: .named)))"
        }
        return text
    }
}

#Preview {
    SyncStatusView()
        .environment(iCloudSyncService())
        .padding()
}
