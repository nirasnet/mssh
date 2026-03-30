import SwiftUI

struct LockScreenView: View {
    var onUnlock: () -> Void

    @State private var isAuthenticating = false
    @State private var showError = false

    private var biometricLabel: String {
        switch BiometricService.biometricType() {
        case .faceID:
            return "Unlock with Face ID"
        case .touchID:
            return "Unlock with Touch ID"
        case .none:
            return "Unlock"
        }
    }

    private var biometricIcon: String {
        switch BiometricService.biometricType() {
        case .faceID:
            return "faceid"
        case .touchID:
            return "touchid"
        case .none:
            return "lock.open"
        }
    }

    var body: some View {
        ZStack {
            // Blurred background
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                Image(systemName: "terminal.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.tint)

                Text("mSSH")
                    .font(.largeTitle.bold())

                Text("Authentication Required")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    performAuth()
                } label: {
                    Label(biometricLabel, systemImage: biometricIcon)
                        .font(.headline)
                        .frame(maxWidth: 280)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isAuthenticating)

                if showError {
                    Text("Authentication failed. Try again.")
                        .font(.footnote)
                        .foregroundStyle(.red)
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
