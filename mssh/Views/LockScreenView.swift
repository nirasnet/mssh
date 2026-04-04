import SwiftUI

struct LockScreenView: View {
    var onUnlock: () -> Void

    @State private var isAuthenticating = false
    @State private var showError = false

    private var biometricLabel: String {
        switch BiometricService.biometricType() {
        case .faceID: return "Unlock with Face ID"
        case .touchID: return "Unlock with Touch ID"
        case .none: return "Unlock"
        }
    }

    private var biometricIcon: String {
        switch BiometricService.biometricType() {
        case .faceID: return "faceid"
        case .touchID: return "touchid"
        case .none: return "lock.open"
        }
    }

    var body: some View {
        ZStack {
            // Dark background
            AppColors.background
                .ignoresSafeArea()

            VStack(spacing: AppSpacing.xxl) {
                Spacer()

                // App icon area
                VStack(spacing: AppSpacing.lg) {
                    ZStack {
                        Circle()
                            .fill(AppColors.surface)
                            .frame(width: 88, height: 88)
                            .overlay(
                                Circle()
                                    .strokeBorder(AppColors.border, lineWidth: 0.5)
                            )
                        Image(systemName: "terminal.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(AppColors.accent)
                    }

                    Text("mSSH")
                        .font(.system(size: 28, weight: .bold, design: .monospaced))
                        .foregroundStyle(AppColors.textPrimary)

                    Text("Authentication Required")
                        .font(.subheadline)
                        .foregroundStyle(AppColors.textSecondary)
                }

                Spacer()

                // Unlock button
                VStack(spacing: AppSpacing.md) {
                    Button {
                        performAuth()
                    } label: {
                        HStack(spacing: AppSpacing.sm) {
                            Image(systemName: biometricIcon)
                                .font(.system(size: 18))
                            Text(biometricLabel)
                                .font(.system(.body, weight: .semibold))
                        }
                        .frame(maxWidth: 280)
                        .padding(.vertical, AppSpacing.md)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppColors.accent)
                    .disabled(isAuthenticating)

                    if showError {
                        Text("Authentication failed. Try again.")
                            .font(.caption)
                            .foregroundStyle(AppColors.error)
                    }
                }

                Spacer()
                    .frame(height: 60)
            }
        }
        .onAppear {
            performAuth()
        }
    }

    private func performAuth() {
        guard !isAuthenticating else { return }
        isAuthenticating = true
        showError = false

        Task {
            let success = await BiometricService.authenticate(
                reason: "Authenticate to access your SSH connections"
            )
            await MainActor.run {
                isAuthenticating = false
                if success {
                    onUnlock()
                } else {
                    showError = true
                }
            }
        }
    }
}
