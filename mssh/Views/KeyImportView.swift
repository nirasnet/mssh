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
                Section("Key Details") {
                    TextField("Label", text: $label)
                        .textInputAutocapitalization(.never)
                }

                Section("Private Key (PEM)") {
                    TextEditor(text: $pemText)
                        .font(.system(.caption, design: .monospaced))
                        .frame(minHeight: 150)

                    Button("Import from File") {
                        showFilePicker = true
                    }
                }

                Section {
                    Text("Paste your PEM-encoded private key or import from a file. The key will be stored in the iOS Keychain.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Import Key")
            .navigationBarTitleDisplayMode(.inline)
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
    }
}
