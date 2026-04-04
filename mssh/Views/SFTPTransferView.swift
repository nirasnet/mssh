import SwiftUI

struct SFTPTransferView: View {
    let fileName: String
    let progress: Double
    let transferType: SFTPViewModel.TransferType

    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            Image(systemName: transferType == .download ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                .font(.system(size: 36))
                .foregroundStyle(AppColors.accent)
                .symbolEffect(.pulse, isActive: progress < 1.0)

            Text(transferType == .download ? "Downloading" : "Uploading")
                .font(.system(.subheadline, design: .monospaced).weight(.medium))
                .foregroundStyle(AppColors.textPrimary)

            Text(fileName)
                .font(AppFonts.monoCaption)
                .foregroundStyle(AppColors.textSecondary)
                .lineLimit(1)
                .truncationMode(.middle)

            if progress < 1.0 {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(AppColors.accent)
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(AppColors.connected)
            }
        }
        .padding(AppSpacing.xl)
        .background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(AppColors.border, lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.4), radius: 20)
    }
}
