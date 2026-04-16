import SwiftUI
import SwiftData

/// CRUD UI for `Snippet` (saved commands). Reachable from Settings and used
/// by the terminal accessory bar / toolbar to push commands to an active
/// session.
struct SnippetsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [
        SortDescriptor(\Snippet.lastUsedAt, order: .reverse),
        SortDescriptor(\Snippet.label, comparator: .localizedStandard)
    ]) private var snippets: [Snippet]

    @State private var editingSnippet: Snippet?
    @State private var showCreateSheet = false

    var body: some View {
        Group {
            if snippets.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(snippets) { snippet in
                        Button {
                            editingSnippet = snippet
                        } label: {
                            SnippetRow(snippet: snippet)
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(AppColors.surface)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                modelContext.delete(snippet)
                                try? modelContext.save()
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
                .background(AppColors.background)
            }
        }
        .background(AppColors.background)
        .navigationTitle("Snippets")
        .iOSOnlyNavigationBarTitleDisplayMode()
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showCreateSheet = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .symbolRenderingMode(.hierarchical)
                        .font(.title3)
                }
            }
        }
        .sheet(isPresented: $showCreateSheet) {
            SnippetEditorView(snippet: nil)
        }
        .sheet(item: $editingSnippet) { snippet in
            SnippetEditorView(snippet: snippet)
        }
    }

    private var emptyState: some View {
        VStack(spacing: AppSpacing.md) {
            Image(systemName: "text.badge.plus")
                .font(.system(size: 36))
                .foregroundStyle(AppColors.textTertiary)
            Text("No Snippets")
                .font(AppFonts.subheading)
                .foregroundStyle(AppColors.textSecondary)
            Text("Save commands you run often, then send them to any active session with one tap.")
                .font(.caption)
                .foregroundStyle(AppColors.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.xl)
            Button {
                showCreateSheet = true
            } label: {
                Text("Add Snippet")
                    .font(AppFonts.label)
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.vertical, AppSpacing.sm)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppColors.accent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Row

private struct SnippetRow: View {
    let snippet: Snippet

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(AppColors.accentDim)
                    .frame(width: 36, height: 36)
                Image(systemName: "chevron.right.circle")
                    .font(.system(size: 14))
                    .foregroundStyle(AppColors.accent)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(snippet.label.isEmpty ? "(untitled)" : snippet.label)
                    .font(.system(.subheadline, design: .default).weight(.medium))
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(1)
                Text(snippet.command)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(AppColors.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            if snippet.useCount > 0 {
                Text("×\(snippet.useCount)")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(AppColors.accent)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(AppColors.accentDim)
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Editor sheet

struct SnippetEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let snippet: Snippet?

    @State private var label = ""
    @State private var command = ""

    private var isValid: Bool {
        !command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Label", text: $label, prompt: Text("e.g. Tail syslog").foregroundStyle(AppColors.textTertiary))
                        .iOSOnlyTextInputAutocapitalization()
                        .autocorrectionDisabled()
                } header: {
                    Text("Label")
                } footer: {
                    Text("A short name shown in the snippet picker.")
                }

                Section {
                    TextEditor(text: $command)
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 120)
                        .scrollContentBackground(.hidden)
                        .iOSOnlyTextInputAutocapitalization()
                        .autocorrectionDisabled()
                } header: {
                    Text("Command")
                } footer: {
                    Text("Sent verbatim to the active session. Add a trailing newline to auto-execute.")
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppColors.background)
            .navigationTitle(snippet == nil ? "New Snippet" : "Edit Snippet")
            .iOSOnlyNavigationBarTitleDisplayMode()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(!isValid)
                }
            }
            .onAppear {
                if let s = snippet {
                    label = s.label
                    command = s.command
                }
            }
        }
        .appTheme()
    }

    private func save() {
        let trimmedLabel = label.trimmingCharacters(in: .whitespacesAndNewlines)
        let cmd = command.trimmingCharacters(in: .newlines)

        if let existing = snippet {
            existing.label = trimmedLabel
            existing.command = cmd
        } else {
            let new = Snippet(label: trimmedLabel, command: cmd)
            modelContext.insert(new)
        }
        try? modelContext.save()
    }
}

// MARK: - Picker (used by terminal toolbar)

/// Quick snippet picker shown as a sheet from the terminal toolbar. Tapping
/// a row dismisses and invokes `onPick` with the snippet.
struct SnippetPickerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: [
        SortDescriptor(\Snippet.lastUsedAt, order: .reverse),
        SortDescriptor(\Snippet.label, comparator: .localizedStandard)
    ]) private var snippets: [Snippet]

    let onPick: (Snippet) -> Void

    var body: some View {
        NavigationStack {
            Group {
                if snippets.isEmpty {
                    VStack(spacing: AppSpacing.md) {
                        Image(systemName: "text.badge.plus")
                            .font(.system(size: 32))
                            .foregroundStyle(AppColors.textTertiary)
                        Text("No Snippets Yet")
                            .font(AppFonts.subheading)
                            .foregroundStyle(AppColors.textSecondary)
                        Text("Add snippets in Settings → Snippets.")
                            .font(.caption)
                            .foregroundStyle(AppColors.textTertiary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(AppColors.background)
                } else {
                    List(snippets) { snippet in
                        Button {
                            // Bump use stats
                            snippet.useCount += 1
                            snippet.lastUsedAt = Date()
                            try? modelContext.save()
                            onPick(snippet)
                            dismiss()
                        } label: {
                            SnippetRow(snippet: snippet)
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(AppColors.surface)
                    }
                    .scrollContentBackground(.hidden)
                    .background(AppColors.background)
                }
            }
            .background(AppColors.background)
            .navigationTitle("Snippets")
            .iOSOnlyNavigationBarTitleDisplayMode()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .appTheme()
    }
}
