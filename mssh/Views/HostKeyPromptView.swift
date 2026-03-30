import SwiftUI

struct HostKeyPromptView: View {
    let promptType: HostKeyPromptType
    let onAccept: () -> Void
    let onReject: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            headerSection
            Divider()
            detailSection
            Divider()
            buttonSection
        }
        .frame(maxWidth: 360)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
        .padding(24)
    }

    // MARK: - Sections

    @ViewBuilder
    private var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: iconName)
                .font(.system(size: 36))
                .foregroundStyle(iconColor)
            Text(titleText)
                .font(.headline)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 12)
    }

    @ViewBuilder
    private var detailSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(messageText)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            switch promptType {
            case .newHost(let fingerprint, let keyType):
                fingerprintRow(label: "Key type", value: keyType)
                fingerprintRow(label: "Fingerprint", value: fingerprint)

            case .changedKey(let oldFingerprint, let newFingerprint, let keyType):
                fingerprintRow(label: "Key type", value: keyType)
                fingerprintRow(label: "Previously trusted", value: oldFingerprint)
                fingerprintRow(label: "Now presented", value: newFingerprint)
            }
        }
        .padding(16)
    }

    @ViewBuilder
    private var buttonSection: some View {
        HStack(spacing: 12) {
            Button(role: .cancel, action: onReject) {
                Text("Reject")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            Button(action: onAccept) {
                Text(acceptButtonText)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(acceptButtonTint)
        }
        .padding(16)
    }

    // MARK: - Subviews

    @ViewBuilder
    private func fingerprintRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)
        }
    }

    // MARK: - Computed Properties

    private var iconName: String {
        switch promptType {
        case .newHost:
            return "key.fill"
        case .changedKey:
            return "exclamationmark.triangle.fill"
        }
    }

    private var iconColor: Color {
        switch promptType {
        case .newHost:
            return .blue
        case .changedKey:
            return .red
        }
    }

    private var titleText: String {
        switch promptType {
        case .newHost:
            return "Unknown Host Key"
        case .changedKey:
            return "Host Key Changed"
        }
    }

    private var messageText: String {
        switch promptType {
        case .newHost:
            return "This is the first time connecting to this host. Verify the fingerprint before continuing."
        case .changedKey:
            return "WARNING: The host key has changed since the last connection. This could indicate a man-in-the-middle attack, or the server was reinstalled."
        }
    }

    private var acceptButtonText: String {
        switch promptType {
        case .newHost:
            return "Trust"
        case .changedKey:
            return "Trust Anyway"
        }
    }

    private var acceptButtonTint: Color {
        switch promptType {
        case .newHost:
            return .blue
        case .changedKey:
            return .red
        }
    }
}
