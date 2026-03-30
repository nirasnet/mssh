import SwiftUI

struct SFTPTransferView: View {
    let fileName: String
    let progress: Double
    let transferType: SFTPViewModel.TransferType

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: transferType == .download ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                .font(.system(size: 40))
                .foregroundStyle(transferType == .download ? .blue : .green)
                .symbolEffect(.pulse, isActive: progress < 1.0)

            Text(transferType == .download ? "Downloading" : "Uploading")
                .font(.headline)

            Text(fileName)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)

            if progress < 1.0 {
                ProgressView()
                    .progressViewStyle(.circular)
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.green)
            }
        }
        .padding(32)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .shadow(radius: 10)
    }
}
