import SwiftUI
import UniformTypeIdentifiers

struct KeyImportView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    var viewModel: KeyManagerViewModel

    @State private var label = ""
    @State private var pemText = ""
    @State private var showFilePicker = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Label", text: $label)
                        .font(.system(.body, design: .monospaced))
                        .iOSOnlyTextInputAutocapitalization()
                } header: {
                    Text("Key Name")
                }

                Section {
                    TextEditor(text: $pemText)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(AppColors.textPrimary)
                        .frame(minHeight: 150)
                        .scrollContentBackground(.hidden)

                    Button {
                        showFilePicker = true
                    } label: {
                        Label("Import from File", systemImage: "doc.badge.arrow.up")
                    }
                } header: {
                    Text("Private Key (PEM)")
                } footer: {
                    Text("Paste your PEM-encoded private key or import from a file. Stored securely in the iOS Keychain.")
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppColors.background)
            .navigationTitle("Import Key")
            .iOSOnlyNavigationBarTitleDisplayMode()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Import") {
                        viewModel.importKey(
                            label: label.isEmpty ? "Imported Key" : label,
                            pemText: pemText,
                            modelContext: modelContext
                        )
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(pemText.isEmpty)
                }
            }
            .fileImporter(
                isPresented: $showFilePicker,
                allowedContentTypes: [.plainText, .data],
                allowsMultipleSelection: false
            ) { result in
                if case .success(let urls) = result, let url = urls.first {
                    if url.startAccessingSecurityScopedResource() {
                        defer { url.stopAccessingSecurityScopedResource() }
                        if let data = try? Data(contentsOf: url),
                           let text = String(data: data, encoding: .utf8) {
                            pemText = text
                            if label.isEmpty {
                                label = url.deletingPathExtension().lastPathComponent
                            }
                        }
                    }
                }
            }
        }
        .appTheme()
    }
}
