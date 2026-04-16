import SwiftUI
import SwiftData

struct KeyManagerView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var keys: [SSHKey]
    @State private var showGenerateSheet = false
    @State private var showImportSheet = false
    @State private var showImportWizard = false
    @State private var showConfigImport = false
    @State private var showMacGuide = false
    @State private var viewModel = KeyManagerViewModel()
    @State private var renamingKey: SSHKey?
    @State private var renameDraft = ""

    var body: some View {
        Group {
            if keys.isEmpty {
                emptyState
            } else {
                keyList
            }
        }
        .background(AppColors.background)
        .navigationTitle("SSH Keys")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Section("Create") {
                        Button {
                            showGenerateSheet = true
                        } label: {
                            Label("Generate Ed25519 Key", systemImage: "plus.circle")
                        }
                    }

                    Section("Import") {
                        Button {
                            showImportSheet = true
                        } label: {
                            Label("Paste Key", systemImage: "doc.on.clipboard")
                        }
                        Button {
                            showImportWizard = true
                        } label: {
                            Label("Import Wizard", systemImage: "wand.and.stars")
                        }
                        Button {
                            showConfigImport = true
                        } label: {
                            Label("SSH Config", systemImage: "doc.text")
                        }
                    }

                    Section("Help") {
                        Button {
                            showMacGuide = true
                        } label: {
                            Label("Mac Setup Guide", systemImage: "laptopcomputer.and.iphone")
                        }
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .symbolRenderingMode(.hierarchical)
                }
            }
        }
        .sheet(isPresented: $showGenerateSheet) {
            GenerateKeySheet(viewModel: viewModel)
        }
        .sheet(isPresented: $showImportSheet) {
            KeyImportView(viewModel: viewModel)
        }
        .sheet(isPresented: $showImportWizard) {
            KeyImportWizardView()
                .modelContainer(modelContext.container)
        }
        .sheet(isPresented: $showConfigImport) {
            SSHConfigImportView()
        }
        .sheet(isPresented: $showMacGuide) {
            MacSetupGuideView()
        }
        .alert("Error", isPresented: .init(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .alert("Rename Key",
               isPresented: .init(
                   get: { renamingKey != nil },
                   set: { if !$0 { renamingKey = nil } }
               ),
               presenting: renamingKey
        ) { _ in
            TextField("Label", text: $renameDraft)
                .iOSOnlyTextInputAutocapitalization()
                .autocorrectionDisabled()
            Button("Save") {
                if let key = renamingKey {
                    viewModel.renameKey(key, to: renameDraft, modelContext: modelContext)
                }
                renamingKey = nil
            }
            Button("Cancel", role: .cancel) {
                renamingKey = nil
            }
        } message: { key in
            Text("Rename \"\(key.label)\" to:")
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: AppSpacing.lg) {
            Spacer()

            Image(systemName: "key.fill")
                .font(.system(size: 48))
                .foregroundStyle(AppColors.textTertiary)

            Text("No SSH Keys")
                .font(AppFonts.heading)
                .foregroundStyle(AppColors.textPrimary)

            Text("Generate or import keys for\npasswordless authentication")
                .font(.subheadline)
                .foregroundStyle(AppColors.textSecondary)
                .multilineTextAlignment(.center)

            VStack(spacing: AppSpacing.sm) {
                Button {
                    showGenerateSheet = true
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Generate Ed25519 Key")
                    }
                    .frame(maxWidth: 260)
                }
                .buttonStyle(.borderedProminent)

                Button {
                    showImportWizard = true
                } label: {
                    HStack {
                        Image(systemName: "square.and.arrow.down")
                        Text("Import Existing Key")
                    }
                    .frame(maxWidth: 260)
                }
                .buttonStyle(.bordered)

                Button {
                    showMacGuide = true
                } label: {
                    Text("Mac Setup Guide")
                        .font(.caption)
                        .foregroundStyle(AppColors.accent)
                }
                .padding(.top, AppSpacing.xs)
            }
            .padding(.top, AppSpacing.md)

            Spacer()
        }
    }

    // MARK: - Key List

    private var keyList: some View {
        ScrollView {
            VStack(spacing: AppSpacing.sm) {
                ForEach(keys) { key in
                    keyCard(key)
                }
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.top, AppSpacing.sm)
            .padding(.bottom, AppSpacing.xxl)
        }
    }

    private func keyCard(_ key: SSHKey) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                Text(key.label)
                    .font(.system(.subheadline, design: .monospaced).weight(.medium))
                    .foregroundStyle(AppColors.textPrimary)
                Spacer()
                Text(key.keyType.uppercased())
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(AppColors.accent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(AppColors.accentDim)
                    .clipShape(Capsule())
            }

            Text(key.publicKeyText)
                .font(AppFonts.monoCaption)
                .foregroundStyle(AppColors.textTertiary)
                .lineLimit(2)

            HStack {
                Text("Created \(key.createdAt.formatted(.relative(presentation: .named)))")
                    .font(.system(size: 10))
                    .foregroundStyle(AppColors.textTertiary)
                Spacer()
            }
        }
        .appCard()
        .contextMenu {
            Button {
                AppClipboard.copy(key.publicKeyText)
            } label: {
                Label("Copy Public Key", systemImage: "doc.on.doc")
            }
            Button {
                renameDraft = key.label
                renamingKey = key
            } label: {
                Label("Rename", systemImage: "pencil")
            }
            Divider()
            Button(role: .destructive) {
                viewModel.deleteKey(key, modelContext: modelContext)
            } label: {
                Label("Delete Key", systemImage: "trash")
            }
        }
    }
}

// MARK: - Generate Key Sheet

struct GenerateKeySheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    var viewModel: KeyManagerViewModel
    @State private var label = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Key Label", text: $label)
                        .font(.system(.body, design: .monospaced))
                        .iOSOnlyTextInputAutocapitalization()
                } header: {
                    Text("Name")
                }

                Section {
                    HStack(spacing: AppSpacing.md) {
                        Image(systemName: "shield.checkered")
                            .font(.title3)
                            .foregroundStyle(AppColors.accent)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Ed25519")
                                .font(.system(.subheadline, design: .monospaced).weight(.medium))
                            Text("Modern, fast, and secure. Recommended for all use.")
                                .font(.caption)
                                .foregroundStyle(AppColors.textSecondary)
                        }
                    }
                } header: {
                    Text("Algorithm")
                } footer: {
                    Text("The private key is stored in the iOS Keychain and never leaves this device.")
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppColors.background)
            .navigationTitle("Generate Key")
            .iOSOnlyNavigationBarTitleDisplayMode()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Generate") {
                        viewModel.generateKey(label: label.isEmpty ? "My Key" : label, modelContext: modelContext)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .appTheme()
    }
}
