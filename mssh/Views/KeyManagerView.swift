import SwiftUI
import SwiftData

struct KeyManagerView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var keys: [SSHKey]
    @State private var showGenerateSheet = false
    @State private var showImportSheet = false
    @State private var viewModel = KeyManagerViewModel()

    var body: some View {
        List {
            if keys.isEmpty {
                ContentUnavailableView(
                    "No SSH Keys",
                    systemImage: "key",
                    description: Text("Generate or import keys to use key-based authentication.")
                )
            }

            ForEach(keys) { key in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(key.label)
                            .font(.headline)
                        Spacer()
                        Text(key.keyType.uppercased())
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.accentColor.opacity(0.15))
                            .cornerRadius(4)
                    }

                    Text(key.publicKeyText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)

                    Text("Created \(key.createdAt.formatted(.relative(presentation: .named)))")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .padding(.vertical, 4)
                .contextMenu {
                    Button {
                        UIPasteboard.general.string = key.publicKeyText
                    } label: {
                        Label("Copy Public Key", systemImage: "doc.on.doc")
                    }
                    Button(role: .destructive) {
                        viewModel.deleteKey(key, modelContext: modelContext)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
            .onDelete { indexSet in
                for index in indexSet {
                    viewModel.deleteKey(keys[index], modelContext: modelContext)
                }
            }
        }
        .navigationTitle("SSH Keys")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("Generate New Key", systemImage: "plus") {
                        showGenerateSheet = true
                    }
                    Button("Import Key", systemImage: "square.and.arrow.down") {
                        showImportSheet = true
                    }
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showGenerateSheet) {
            GenerateKeySheet(viewModel: viewModel)
        }
        .sheet(isPresented: $showImportSheet) {
            KeyImportView(viewModel: viewModel)
        }
        .alert("Error", isPresented: .init(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }
}

struct GenerateKeySheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    var viewModel: KeyManagerViewModel
    @State private var label = ""

    var body: some View {
        NavigationStack {
            Form {
                TextField("Key Label", text: $label)
                    .textInputAutocapitalization(.never)

                Section {
                    Text("Generates an Ed25519 key pair. The private key is stored securely in the iOS Keychain.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Generate Key")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Generate") {
                        viewModel.generateKey(label: label.isEmpty ? "My Key" : label, modelContext: modelContext)
                        dismiss()
                    }
                }
            }
        }
    }
}
