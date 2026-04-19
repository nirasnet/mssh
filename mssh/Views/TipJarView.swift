import SwiftUI
import StoreKit

/// Inline tip jar view for the Settings screen.
struct TipJarView: View {
    @State private var tipJar = TipJarService.shared
    @State private var showThankYou = false

    var body: some View {
        Group {
            if tipJar.isLoading && tipJar.products.isEmpty {
                HStack {
                    Spacer()
                    ProgressView()
                        .controlSize(.small)
                        .tint(AppColors.accent)
                    Text("Loading tips...")
                        .font(.caption)
                        .foregroundStyle(AppColors.textSecondary)
                    Spacer()
                }
            } else if tipJar.products.isEmpty {
                VStack(spacing: AppSpacing.sm) {
                    Text("Tips loading — if this persists, tips may not be available yet in your region.")
                        .font(.caption)
                        .foregroundStyle(AppColors.textTertiary)
                    Button {
                        Task { await tipJar.loadProducts() }
                    } label: {
                        Label("Retry", systemImage: "arrow.clockwise")
                            .font(.caption)
                            .foregroundStyle(AppColors.accent)
                    }
                }
            } else {
                ForEach(tipJar.products, id: \.id) { product in
                    tipRow(product)
                }
            }

            // GitHub Sponsors link
            Link(destination: URL(string: "https://github.com/nirasnet/mssh")!) {
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "star.circle")
                        .foregroundStyle(AppColors.accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Star on GitHub")
                            .font(.subheadline)
                            .foregroundStyle(AppColors.textPrimary)
                        Text("github.com/nirasnet/mssh")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(AppColors.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "arrow.up.right.square")
                        .font(.caption)
                        .foregroundStyle(AppColors.textTertiary)
                }
            }
        }
        .task {
            await tipJar.loadProducts()
        }
        .alert("Thank You!", isPresented: $showThankYou) {
            Button("OK") {}
        } message: {
            Text(tipJar.purchaseMessage ?? "Your support means a lot!")
        }
        .onChange(of: tipJar.purchaseMessage) {
            if tipJar.purchaseMessage != nil {
                showThankYou = true
            }
        }
    }

    private func tipRow(_ product: Product) -> some View {
        let info = TipJarService.tierInfo(for: product)
        return Button {
            Task { await tipJar.purchase(product) }
        } label: {
            HStack(spacing: AppSpacing.md) {
                Text(info.emoji)
                    .font(.title2)
                VStack(alignment: .leading, spacing: 2) {
                    Text(info.subtitle)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(AppColors.textPrimary)
                    Text(product.displayPrice)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(AppColors.accent)
                }
                Spacer()
                if tipJar.isLoading {
                    ProgressView()
                        .controlSize(.small)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(tipJar.isLoading)
    }
}
