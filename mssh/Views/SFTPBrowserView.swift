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
                VStack(spacing: 0) {
                    // Breadcrumb bar
                    breadcrumbBar

                    // File list
                    fileList
                }

                // Transfer overlay
                if viewModel.isTransferring {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()

                    SFTPTransferView(
                        fileName: viewModel.transferFileName,
                        progress: viewModel.transferProgress,
                        transferType: viewModel.transferType
                    )
                }
            }
            .navigationTitle("SFTP Browser")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItemGroup(placement: .primaryAction) {
                    Button {
                        viewModel.showNewFolderAlert = true
                    } label: {
                        Image(systemName: "folder.badge.plus")
                    }

                    Button {
                        viewModel.showFileImporter = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
                ToolbarItem(placement: .bottomBar) {
                    HStack {
                        Text("\(viewModel.files.count) items")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                }
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
    }

    // MARK: - Breadcrumb Bar

    private var breadcrumbBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                Button {
                    Task { await viewModel.goBack() }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.caption)
                }
                .disabled(viewModel.pathHistory.isEmpty)

                ForEach(Array(viewModel.breadcrumbs.enumerated()), id: \.element.id) { index, crumb in
                    if index > 0 {
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    Button {
                        Task { await viewModel.navigateToBreadcrumb(crumb.path) }
                    } label: {
                        Text(crumb.name)
                            .font(.caption)
                            .fontWeight(index == viewModel.breadcrumbs.count - 1 ? .semibold : .regular)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .background(Color(UIColor.secondarySystemBackground))
    }

    // MARK: - File List

    private var fileList: some View {
        Group {
            if viewModel.isLoading && viewModel.files.isEmpty {
                ContentUnavailableView {
                    ProgressView()
                } description: {
                    Text("Loading...")
                }
            } else if viewModel.files.isEmpty && !viewModel.isLoading {
                ContentUnavailableView(
                    "Empty Directory",
                    systemImage: "folder",
                    description: Text("This directory has no files.")
                )
            } else {
                List {
                    // Go up row
                    if viewModel.currentPath != "/" {
                        Button {
                            Task { await viewModel.goUp() }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "arrow.up.doc.fill")
                                    .foregroundStyle(.secondary)
                                    .frame(width: 28)
                                Text("..")
                                    .foregroundStyle(.primary)
                                Spacer()
                            }
                        }
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
                                    .tint(.blue)
                                }
                            }
                    }
                }
                .listStyle(.plain)
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
            HStack(spacing: 12) {
                Image(systemName: item.iconName)
                    .foregroundStyle(item.iconColor)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        if !item.isDirectory {
                            Text(item.formattedSize)
                        }
                        Text(item.formattedDate)
                        Text(item.formattedPermissions)
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }

                Spacer()

                if item.isDirectory {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }
}
