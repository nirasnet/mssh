import SwiftUI
import SwiftData
import UniformTypeIdentifiers

// MARK: - Import Source

enum KeyImportSource: String, CaseIterable, Identifiable {
    case iCloudDrive = "iCloud Drive"
    case files = "Files"
    case clipboard = "Clipboard"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .iCloudDrive: return "icloud"
        case .files: return "folder"
        case .clipboard: return "doc.on.clipboard"
        }
    }

    var description: String {
        switch self {
        case .iCloudDrive: return "Browse iCloud Drive for SSH keys shared from your Mac"
        case .files: return "Pick key files from any accessible location"
        case .clipboard: return "Paste a private key copied to the clipboard"
        }
    }
}

// MARK: - Wizard Step

private enum WizardStep: Int, CaseIterable {
    case chooseSource = 0
    case previewKeys = 1
    case confirm = 2

    var title: String {
        switch self {
        case .chooseSource: return "Choose Source"
        case .previewKeys: return "Preview Keys"
        case .confirm: return "Confirm Import"
        }
    }
}

// MARK: - Selection State for Preview

private struct KeySelection: Identifiable {
    let id = UUID()
    let preview: SSHKeyPreview
    var selected: Bool
    var label: String
}

// MARK: - Main View

struct KeyImportWizardView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    /// Callback fired after successful import so the parent can refresh.
    var onImported: (() -> Void)?

    @State private var step: WizardStep = .chooseSource
    @State private var selectedSource: KeyImportSource?
    @State private var keySelections: [KeySelection] = []
    @State private var showFilePicker = false
    @State private var clipboardText = ""
    @State private var isImporting = false
    @State private var importResults: (imported: Int, errors: Int)?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Progress indicator
                stepIndicator

                Divider()

                // Step content
                Group {
                    switch step {
                    case .chooseSource:
                        sourceSelectionView
                    case .previewKeys:
                        keyPreviewView
                    case .confirm:
                        confirmationView
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationTitle("Import SSH Keys")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if step == .confirm {
                        Button("Import") {
                            performImport()
                        }
                        .bold()
                        .disabled(keySelections.filter(\.selected).isEmpty || isImporting)
                    }
                }
            }
            .fileImporter(
                isPresented: $showFilePicker,
                allowedContentTypes: [.plainText, .data, .item],
                allowsMultipleSelection: true
            ) { result in
                handleFilePickerResult(result)
            }
            .alert("Import Complete", isPresented: .init(
                get: { importResults != nil },
                set: { if !$0 { importResults = nil } }
            )) {
                Button("Done") {
                    importResults = nil
                    onImported?()
                    dismiss()
                }
            } message: {
                if let results = importResults {
                    if results.errors > 0 {
                        Text("Imported \(results.imported) key(s). \(results.errors) key(s) failed.")
                    } else {
                        Text("Successfully imported \(results.imported) key(s).")
                    }
                }
            }
            .alert("Error", isPresented: .init(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    // MARK: - Step Indicator

    private var stepIndicator: some View {
        HStack(spacing: 0) {
            ForEach(WizardStep.allCases, id: \.rawValue) { s in
                VStack(spacing: 4) {
                    Circle()
                        .fill(s.rawValue <= step.rawValue ? Color.accentColor : Color.secondary.opacity(0.3))
                        .frame(width: 28, height: 28)
                        .overlay {
                            if s.rawValue < step.rawValue {
                                Image(systemName: "checkmark")
                                    .font(.caption.bold())
                                    .foregroundStyle(.white)
                            } else {
                                Text("\(s.rawValue + 1)")
                                    .font(.caption.bold())
                                    .foregroundStyle(s.rawValue <= step.rawValue ? .white : .secondary)
                            }
                        }

                    Text(s.title)
                        .font(.caption2)
                        .foregroundStyle(s.rawValue <= step.rawValue ? .primary : .secondary)
                }
                .frame(maxWidth: .infinity)

                if s.rawValue < WizardStep.allCases.count - 1 {
                    Rectangle()
                        .fill(s.rawValue < step.rawValue ? Color.accentColor : Color.secondary.opacity(0.3))
                        .frame(height: 2)
                        .frame(maxWidth: 40)
                        .padding(.bottom, 18)
                }
            }
        }
        .padding()
    }

    // MARK: - Step 1: Source Selection

    private var sourceSelectionView: some View {
        List {
            Section {
                ForEach(KeyImportSource.allCases) { source in
                    Button {
                        selectedSource = source
                        handleSourceSelection(source)
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: source.icon)
                                .font(.title2)
                                .foregroundStyle(Color.accentColor)
                                .frame(width: 36)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(source.rawValue)
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                Text(source.description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            } header: {
                Text("Where are your SSH keys?")
            } footer: {
                Text("Select a source to browse for private key files. Keys shared from your Mac via iCloud Drive are the easiest option.")
            }
        }
    }

    // MARK: - Step 2: Key Preview

    private var keyPreviewView: some View {
        VStack {
            if keySelections.isEmpty {
                ContentUnavailableView(
                    "No Keys Found",
                    systemImage: "key.slash",
                    description: Text("No valid SSH private keys were detected in the selected files.")
                )
            } else {
                List {
                    Section {
                        ForEach($keySelections) { $selection in
                            HStack {
                                Toggle(isOn: $selection.selected) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack {
                                            Text(selection.preview.fileName)
                                                .font(.headline)
                                            Spacer()
                                            Text(selection.preview.keyType.shortName)
                                                .font(.caption)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Color.accentColor.opacity(0.15))
                                                .cornerRadius(4)
                                        }

                                        Text(selection.preview.fingerprint)
                                            .font(.system(.caption, design: .monospaced))
                                            .foregroundStyle(.secondary)

                                        HStack(spacing: 8) {
                                            Text(selection.preview.format.rawValue)
                                                .font(.caption2)
                                                .foregroundStyle(.tertiary)

                                            if selection.preview.isEncrypted {
                                                Label("Encrypted", systemImage: "lock.fill")
                                                    .font(.caption2)
                                                    .foregroundStyle(.orange)
                                            }

                                            if !selection.preview.comment.isEmpty {
                                                Text(selection.preview.comment)
                                                    .font(.caption2)
                                                    .foregroundStyle(.tertiary)
                                            }
                                        }
                                    }
                                }
                                .toggleStyle(.checkbox)
                            }
                            .padding(.vertical, 2)
                        }
                    } header: {
                        Text("Detected Keys (\(keySelections.count))")
                    } footer: {
                        if keySelections.contains(where: { $0.preview.isEncrypted }) {
                            Text("Encrypted keys (marked with a lock) cannot be imported at this time.")
                        }
                    }

                    Section {
                        ForEach($keySelections.filter { $0.selected.wrappedValue }) { $selection in
                            HStack {
                                Text(selection.preview.fileName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 100, alignment: .leading)
                                TextField("Label", text: $selection.label)
                                    .textInputAutocapitalization(.never)
                            }
                        }
                    } header: {
                        Text("Labels")
                    } footer: {
                        Text("Customize the label for each key. This is how it will appear in the key manager.")
                    }
                }
            }

            HStack {
                Button("Back") {
                    withAnimation { step = .chooseSource }
                }

                Spacer()

                let selectedCount = keySelections.filter(\.selected).count
                Button("Continue (\(selectedCount) selected)") {
                    withAnimation { step = .confirm }
                }
                .disabled(selectedCount == 0)
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
    }

    // MARK: - Step 3: Confirmation

    private var confirmationView: some View {
        VStack {
            let selected = keySelections.filter(\.selected)

            List {
                Section("Summary") {
                    LabeledContent("Keys to import", value: "\(selected.count)")

                    ForEach(selected) { sel in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(sel.label)
                                    .font(.subheadline)
                                Text(sel.preview.displayType)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }
                    }
                }

                Section {
                    Label {
                        Text("Private keys will be stored in the iOS Keychain and never leave this device.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } icon: {
                        Image(systemName: "lock.shield.fill")
                            .foregroundStyle(.green)
                    }
                }
            }

            HStack {
                Button("Back") {
                    withAnimation { step = .previewKeys }
                }

                Spacer()

                if isImporting {
                    ProgressView()
                }
            }
            .padding()
        }
    }

    // MARK: - Actions

    private func handleSourceSelection(_ source: KeyImportSource) {
        switch source {
        case .iCloudDrive, .files:
            showFilePicker = true
        case .clipboard:
            handleClipboard()
        }
    }

    private func handleClipboard() {
        guard let text = UIPasteboard.general.string, !text.isEmpty else {
            errorMessage = "The clipboard is empty or does not contain text."
            return
        }

        let format = SSHKeyImporter.detectFormat(text)
        if format == .unknown {
            errorMessage = "The clipboard does not appear to contain an SSH private key."
            return
        }

        let preview = SSHKeyImporter.preview(text: text, fileName: "clipboard-key")
        keySelections = [KeySelection(preview: preview, selected: true, label: "Clipboard Key")]
        withAnimation { step = .previewKeys }
    }

    private func handleFilePickerResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            var selections: [KeySelection] = []

            for url in urls {
                guard url.startAccessingSecurityScopedResource() else { continue }
                defer { url.stopAccessingSecurityScopedResource() }

                guard let data = try? Data(contentsOf: url),
                      let text = String(data: data, encoding: .utf8) else { continue }

                let format = SSHKeyImporter.detectFormat(text)
                if format != .unknown {
                    let preview = SSHKeyImporter.preview(text: text, fileName: url.lastPathComponent)
                    let label = url.deletingPathExtension().lastPathComponent
                    selections.append(KeySelection(
                        preview: preview,
                        selected: !preview.isEncrypted,
                        label: label
                    ))
                }
            }

            keySelections = selections
            withAnimation { step = .previewKeys }

        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }

    private func performImport() {
        isImporting = true

        let selected = keySelections.filter(\.selected)
        var importedCount = 0
        var errorCount = 0
        var lastError: String?

        for selection in selected {
            guard let pemData = selection.preview.rawPEM.data(using: .utf8) else {
                errorCount += 1
                lastError = "Invalid key data for \(selection.label)"
                continue
            }

            do {
                let keychainID = UUID().uuidString
                try KeychainService.savePrivateKey(id: keychainID, pemData: pemData)

                let sshKey = SSHKey(
                    label: selection.label,
                    keyType: selection.preview.keyType.rawValue,
                    keychainID: keychainID,
                    publicKeyText: selection.preview.publicKeyText ?? "(imported \(selection.preview.keyType.shortName) key)"
                )
                modelContext.insert(sshKey)
                importedCount += 1
            } catch {
                errorCount += 1
                lastError = error.localizedDescription
            }
        }

        // Force save
        do {
            try modelContext.save()
        } catch {
            lastError = "Save failed: \(error.localizedDescription)"
            errorCount += 1
        }

        isImporting = false

        if importedCount == 0 {
            errorMessage = lastError ?? "Import failed"
        } else {
            importResults = (imported: importedCount, errors: errorCount)
        }
    }
}

// MARK: - Checkbox Toggle Style

private struct CheckboxToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            Image(systemName: configuration.isOn ? "checkmark.square.fill" : "square")
                .foregroundStyle(configuration.isOn ? Color.accentColor : .secondary)
                .onTapGesture { configuration.isOn.toggle() }
            configuration.label
        }
    }
}

extension ToggleStyle where Self == CheckboxToggleStyle {
    static var checkbox: CheckboxToggleStyle { CheckboxToggleStyle() }
}
