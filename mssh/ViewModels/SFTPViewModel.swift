import Foundation
import Citadel
import Observation
import UniformTypeIdentifiers

@Observable
@MainActor
final class SFTPViewModel {
    var currentPath: String = "/"
    var files: [SFTPFileItem] = []
    var isLoading = false
    var error: String?
    var pathHistory: [String] = []

    // Transfer state
    var isTransferring = false
    var transferFileName: String = ""
    var transferProgress: Double = 0
    var transferType: TransferType = .download

    // New folder state
    var showNewFolderAlert = false
    var newFolderName = ""

    // File importer
    var showFileImporter = false

    // Confirmation dialog
    var itemToDelete: SFTPFileItem?
    var showDeleteConfirmation = false

    enum TransferType {
        case download
        case upload
    }

    private let sftpService: SFTPService

    var breadcrumbs: [PathCrumb] {
        var crumbs: [PathCrumb] = []
        let components = currentPath.split(separator: "/")
        crumbs.append(PathCrumb(name: "/", path: "/"))
        var built = ""
        for component in components {
            built += "/" + component
            crumbs.append(PathCrumb(name: String(component), path: built))
        }
        return crumbs
    }

    init(client: SSHClient) {
        self.sftpService = SFTPService(client: client)
    }

    func loadInitialDirectory() async {
        isLoading = true
        error = nil
        do {
            let home = try await sftpService.getHomePath()
            currentPath = home
            pathHistory = [home]
            try await loadFiles()
        } catch {
            self.error = "Failed to resolve home: \(error.localizedDescription)"
        }
        isLoading = false
    }

    func navigate(to path: String) async {
        pathHistory.append(currentPath)
        currentPath = path
        await refresh()
    }

    func goUp() async {
        let parent = (currentPath as NSString).deletingLastPathComponent
        let target = parent.isEmpty ? "/" : parent
        pathHistory.append(currentPath)
        currentPath = target
        await refresh()
    }

    func goBack() async {
        guard let previous = pathHistory.popLast() else { return }
        currentPath = previous
        await refresh()
    }

    func navigateToBreadcrumb(_ path: String) async {
        if path != currentPath {
            pathHistory.append(currentPath)
            currentPath = path
            await refresh()
        }
    }

    func refresh() async {
        isLoading = true
        error = nil
        do {
            try await loadFiles()
        } catch {
            self.error = "Failed to list directory: \(error.localizedDescription)"
        }
        isLoading = false
    }

    func download(item: SFTPFileItem) async {
        isTransferring = true
        transferFileName = item.name
        transferType = .download
        transferProgress = 0

        do {
            let documentsURL = FileManager.default.urls(
                for: .documentDirectory,
                in: .userDomainMask
            ).first!
            let localURL = documentsURL.appendingPathComponent(item.name)

            try await sftpService.downloadFile(remotePath: item.path, localURL: localURL)
            transferProgress = 1.0
        } catch {
            self.error = "Download failed: \(error.localizedDescription)"
        }

        // Brief delay so user sees completion
        try? await Task.sleep(for: .milliseconds(500))
        isTransferring = false
    }

    func upload(url: URL) async {
        let filename = url.lastPathComponent
        isTransferring = true
        transferFileName = filename
        transferType = .upload
        transferProgress = 0

        do {
            let remotePath: String
            if currentPath.hasSuffix("/") {
                remotePath = currentPath + filename
            } else {
                remotePath = currentPath + "/" + filename
            }

            _ = url.startAccessingSecurityScopedResource()
            defer { url.stopAccessingSecurityScopedResource() }

            try await sftpService.uploadFile(localURL: url, remotePath: remotePath)
            transferProgress = 1.0
            try? await Task.sleep(for: .milliseconds(500))
            isTransferring = false
            await refresh()
        } catch {
            self.error = "Upload failed: \(error.localizedDescription)"
            isTransferring = false
        }
    }

    func delete(item: SFTPFileItem) async {
        do {
            if item.isDirectory {
                try await sftpService.deleteDirectory(path: item.path)
            } else {
                try await sftpService.deleteFile(path: item.path)
            }
            await refresh()
        } catch {
            self.error = "Delete failed: \(error.localizedDescription)"
        }
    }

    func createDirectory() async {
        let name = newFolderName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        do {
            let path: String
            if currentPath.hasSuffix("/") {
                path = currentPath + name
            } else {
                path = currentPath + "/" + name
            }
            try await sftpService.createDirectory(path: path)
            newFolderName = ""
            await refresh()
        } catch {
            self.error = "Create folder failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Private

    private func loadFiles() async throws {
        files = try await sftpService.listDirectory(path: currentPath)
    }
}

struct PathCrumb: Identifiable {
    let id = UUID()
    let name: String
    let path: String
}
