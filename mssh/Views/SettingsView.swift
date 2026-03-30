import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("terminalThemeName") private var themeName = "Default"
    @AppStorage("terminalFontSize") private var fontSize = 13.0

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
