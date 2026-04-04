import SwiftUI
import Citadel

struct SFTPBrowserView: View {
    @State private var viewModel: SFTPViewModel
    @Environment(\.dismiss) private var dismiss

    init(client: SSHClient) {
        _viewModel = State(initialValue: SFTPViewModel(client: client))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    breadcrumbBar
                    fileList
                }

                // Transfer overlay
                if viewModel.isTransferring {
                    Color.black.opacity(0.5)
                        .ignoresSafeArea()

                    SFTPTransferView(
                        fileName: viewModel.transferFileName,
                        progress: viewModel.transferProgress,
                        transferType: viewModel.transferType
                    )
                }
            }
            .navigationTitle("Files")
            .iOSOnlyNavigationBarTitleDisplayMode()
            #if os(iOS)
            .toolbarBackground(AppColors.surface, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.medium)
                }
                ToolbarItemGroup(placement: .primaryAction) {
                    Button {
                        viewModel.showNewFolderAlert = true
                    } label: {
                        Image(systemName: "folder.badge.plus")
                            .font(.system(size: 14))
                    }

                    Button {
                        viewModel.showFileImporter = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 14))
                    }
                }
                #if os(iOS)
                ToolbarItem(placement: .bottomBar) {
                    HStack {
                        Text("\(viewModel.files.count) items")
                            .font(AppFonts.monoCaption)
                            .foregroundStyle(AppColors.textTertiary)
                        Spacer()
                    }
                }
                #endif
            }
            .task {
                await viewModel.loadInitialDirectory()
            }
            .refreshable {
                await viewModel.refresh()
            }
            .alert("New Folder", isPresented: $viewModel.showNewFolderAlert) {
                TextField("Folder name", text: $viewModel.newFolderName)
                Button("Cancel", role: .cancel) {
                    viewModel.newFolderName = ""
                }
                Button("Create") {
                    Task { await viewModel.createDirectory() }
                }
            } message: {
                Text("Enter a name for the new folder.")
            }
            .alert("Error", isPresented: .init(
                get: { viewModel.error != nil },
                set: { if !$0 { viewModel.error = nil } }
            )) {
                Button("OK") { viewModel.error = nil }
            } message: {
                Text(viewModel.error ?? "")
            }
            .confirmationDialog(
                "Delete \(viewModel.itemToDelete?.name ?? "")?",
                isPresented: $viewModel.showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    if let item = viewModel.itemToDelete {
                        Task { await viewModel.delete(item: item) }
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                if let item = viewModel.itemToDelete {
                    Text(item.isDirectory
                         ? "This will delete the directory. It must be empty."
                         : "This file will be permanently deleted.")
                }
            }
            .fileImporter(
                isPresented: $viewModel.showFileImporter,
                allowedContentTypes: [.data],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first {
                        Task { await viewModel.upload(url: url) }
                    }
                case .failure(let error):
                    viewModel.error = "File picker error: \(error.localizedDescription)"
                }
            }
        }
        .appTheme()
    }

    // MARK: - Breadcrumb Bar

    private var breadcrumbBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                Button {
                    Task { await viewModel.goBack() }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppColors.accent)
                }
                .disabled(viewModel.pathHistory.isEmpty)

                ForEach(Array(viewModel.breadcrumbs.enumerated()), id: \.element.id) { index, crumb in
                    if index > 0 {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 8))
                            .foregroundStyle(AppColors.textTertiary)
                    }
                    Button {
                        Task { await viewModel.navigateToBreadcrumb(crumb.path) }
                    } label: {
                        Text(crumb.name)
                            .font(.system(size: 12, design: .monospaced))
                            .fontWeight(index == viewModel.breadcrumbs.count - 1 ? .semibold : .regular)
                            .foregroundStyle(index == viewModel.breadcrumbs.count - 1 ? AppColors.textPrimary : AppColors.textSecondary)
                    }
                }
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.vertical, AppSpacing.sm)
        }
        .background(AppColors.surface)
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundStyle(AppColors.border),
            alignment: .bottom
        )
    }

    // MARK: - File List

    private var fileList: some View {
        Group {
            if viewModel.isLoading && viewModel.files.isEmpty {
                VStack {
                    Spacer()
                    ProgressView()
                        .tint(AppColors.accent)
                    Text("Loading...")
                        .font(AppFonts.monoCaption)
                        .foregroundStyle(AppColors.textSecondary)
                        .padding(.top, AppSpacing.sm)
                    Spacer()
                }
            } else if viewModel.files.isEmpty && !viewModel.isLoading {
                VStack {
                    Spacer()
                    Image(systemName: "folder")
                        .font(.system(size: 36))
                        .foregroundStyle(AppColors.textTertiary)
                    Text("Empty Directory")
                        .font(AppFonts.subheading)
                        .foregroundStyle(AppColors.textSecondary)
                        .padding(.top, AppSpacing.sm)
                    Spacer()
                }
            } else {
                List {
                    if viewModel.currentPath != "/" {
                        Button {
                            Task { await viewModel.goUp() }
                        } label: {
                            HStack(spacing: AppSpacing.md) {
                                Image(systemName: "arrow.up.doc.fill")
                                    .foregroundStyle(AppColors.textTertiary)
                                    .frame(width: 24)
                                Text("..")
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundStyle(AppColors.textSecondary)
                                Spacer()
                            }
                        }
                        .listRowBackground(AppColors.surface)
                    }

                    ForEach(viewModel.files) { item in
                        fileRow(item)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    viewModel.itemToDelete = item
                                    viewModel.showDeleteConfirmation = true
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }

                                if !item.isDirectory {
                                    Button {
                                        Task { await viewModel.download(item: item) }
                                    } label: {
                                        Label("Download", systemImage: "arrow.down.circle")
                                    }
                                    .tint(AppColors.accent)
                                }
                            }
                            .listRowBackground(AppColors.surface)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
    }

    // MARK: - File Row

    private func fileRow(_ item: SFTPFileItem) -> some View {
        Button {
            if item.isDirectory {
                Task { await viewModel.navigate(to: item.path) }
            } else {
                Task { await viewModel.download(item: item) }
            }
        } label: {
            HStack(spacing: AppSpacing.md) {
                Image(systemName: item.iconName)
                    .foregroundStyle(item.iconColor)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(.system(.subheadline, design: .monospaced))
                        .foregroundStyle(AppColors.textPrimary)
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        if !item.isDirectory {
                            Text(item.formattedSize)
                        }
                        Text(item.formattedDate)
                        Text(item.formattedPermissions)
                    }
                    .font(AppFonts.monoCaption)
                    .foregroundStyle(AppColors.textTertiary)
                }

                Spacer()

                if item.isDirectory {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10))
                        .foregroundStyle(AppColors.textTertiary)
                }
            }
        }
    }
}
