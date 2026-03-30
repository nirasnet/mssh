import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("terminalThemeName") private var themeName = "Default"
    @AppStorage("terminalFontSize") private var fontSize = 13.0
    @AppStorage("biometricEnabled") private var biometricEnabled = false
    @AppStorage("lockOnBackground") private var lockOnBackground = true

    private var biometricsAvailable: Bool {
        BiometricService.canUseBiometrics()
    }

    private var biometricLabel: String {
        switch BiometricService.biometricType() {
        case .faceID:
            return "Require Face ID"
        case .touchID:
            return "Require Touch ID"
        case .none:
            return "Require Biometrics"
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Terminal") {
                    Picker("Theme", selection: $themeName) {
                        ForEach(TerminalTheme.allThemes, id: \.name) { theme in
                            Text(theme.name).tag(theme.name)
                        }
                    }

                    HStack {
                        Text("Font Size")
                        Spacer()
                        Text("\(Int(fontSize))pt")
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $fontSize, in: 8...24, step: 1)
                }

                Section {
                    Toggle(biometricLabel, isOn: $biometricEnabled)
                        .disabled(!biometricsAvailable)

                    if biometricEnabled {
                        Toggle("Lock on Background", isOn: $lockOnBackground)
                    }
                } header: {
                    Text("Security")
                } footer: {
                    if !biometricsAvailable {
                        Text("Biometric authentication is not available on this device.")
                    } else if biometricEnabled {
                        Text("The app will require authentication when opened\(lockOnBackground ? " and when returning from background" : "").")
                    }
                }

                Section("SSH") {
                    NavigationLink {
                        KnownHostsView()
                    } label: {
                        Label("Known Hosts", systemImage: "server.rack")
                    }
                }

                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
