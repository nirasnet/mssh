import SwiftUI

struct HostKeyPromptView: View {
    let promptType: HostKeyPromptType
    let onAccept: () -> Void
    let onReject: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            headerSection
            detailSection
            buttonSection
        }
        .frame(maxWidth: 360)
        .background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(isWarning ? AppColors.error.opacity(0.3) : AppColors.accent.opacity(0.3), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.5), radius: 30, y: 10)
        .padding(AppSpacing.xl)
    }

    private var isWarning: Bool {
        if case .changedKey = promptType { return true }
        return false
    }

    // MARK: - Sections

    private var headerSection: some View {
        VStack(spacing: AppSpacing.sm) {
            ZStack {
                Circle()
                    .fill(isWarning ? AppColors.errorDim : AppColors.accentDim)
                    .frame(width: 56, height: 56)
                Image(systemName: isWarning ? "exclamationmark.triangle.fill" : "key.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(isWarning ? AppColors.error : AppColors.accent)
            }

            Text(isWarning ? "Host Key Changed" : "Unknown Host Key")
                .font(.system(.headline, design: .monospaced))
                .foregroundStyle(AppColors.textPrimary)
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.top, AppSpacing.xl)
        .padding(.bottom, AppSpacing.md)
    }

    private var detailSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text(isWarning
                 ? "The host key has changed. This could indicate a MITM attack, or the server was reinstalled."
                 : "First time connecting to this host. Verify the fingerprint before continuing."
            )
            .font(.caption)
            .foregroundStyle(AppColors.textSecondary)
            .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                switch promptType {
                case .newHost(let fingerprint, let keyType):
                    fingerprintRow("Type", keyType)
                    fingerprintRow("Fingerprint", fingerprint)

                case .changedKey(let oldFingerprint, let newFingerprint, let keyType):
                    fingerprintRow("Type", keyType)
                    fingerprintRow("Previous", oldFingerprint)
                    fingerprintRow("Current", newFingerprint)
                }
            }
            .padding(AppSpacing.md)
            .background(AppColors.background)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.bottom, AppSpacing.lg)
    }

    private var buttonSection: some View {
        HStack(spacing: AppSpacing.md) {
            Button(action: onReject) {
                Text("Reject")
                    .font(.system(.subheadline, weight: .medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppSpacing.md)
            }
            .buttonStyle(.bordered)
            .tint(AppColors.textSecondary)

            Button(action: onAccept) {
                Text(isWarning ? "Trust Anyway" : "Trust")
                    .font(.system(.subheadline, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppSpacing.md)
            }
            .buttonStyle(.borderedProminent)
            .tint(isWarning ? AppColors.error : AppColors.accent)
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.bottom, AppSpacing.lg)
    }

    private func fingerprintRow(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(AppColors.textTertiary)
            Text(value)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(AppColors.textPrimary)
                .textSelection(.enabled)
        }
    }
}
