import Foundation
import Citadel
import NIO

final class SFTPService: Sendable {
    private let client: SSHClient

    init(client: SSHClient) {
        self.client = client
    }

    func listDirectory(path: String) async throws -> [SFTPFileItem] {
        try await client.withSFTP { sftp in
            let names = try await sftp.listDirectory(atPath: path)
            var items: [SFTPFileItem] = []

            for name in names {
                for component in name.components {
                    let filename = component.filename
                    // Skip . and ..
                    if filename == "." || filename == ".." {
                        continue
                    }

                    let fullPath: String
                    if path.hasSuffix("/") {
                        fullPath = path + filename
                    } else {
                        fullPath = path + "/" + filename
                    }

                    let isDirectory = Self.isDirectory(permissions: component.attributes.permissions)

                    let modifiedDate = component.attributes.accessModificationTime?.modificationTime

                    let item = SFTPFileItem(
                        name: filename,
                        path: fullPath,
                        isDirectory: isDirectory,
                        size: component.attributes.size,
                        modifiedDate: modifiedDate,
                        permissions: component.attributes.permissions
                    )
                    items.append(item)
                }
            }

            // Sort: directories first, then alphabetically
            items.sort { lhs, rhs in
                if lhs.isDirectory != rhs.isDirectory {
                    return lhs.isDirectory
                }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }

            return items
        }
    }

    func downloadFile(remotePath: String, localURL: URL) async throws {
        try await client.withSFTP { sftp in
            let data = try await sftp.withFile(
                filePath: remotePath,
                flags: .read
            ) { file in
                try await file.readAll()
            }

            let bytes = data.data
            try bytes.write(to: localURL)
        }
    }

    func uploadFile(localURL: URL, remotePath: String) async throws {
        let fileData = try Data(contentsOf: localURL)
        try await client.withSFTP { sftp in
            try await sftp.withFile(
                filePath: remotePath,
                flags: [.write, .create, .truncate]
            ) { file in
                let buffer = ByteBuffer(data: fileData)
                try await file.write(buffer)
            }
        }
    }

    func deleteFile(path: String) async throws {
        try await client.withSFTP { sftp in
            try await sftp.remove(at: path)
        }
    }

    func deleteDirectory(path: String) async throws {
        try await client.withSFTP { sftp in
            try await sftp.rmdir(at: path)
        }
    }

    func createDirectory(path: String) async throws {
        try await client.withSFTP { sftp in
            try await sftp.createDirectory(atPath: path)
        }
    }

    func getHomePath() async throws -> String {
        try await client.withSFTP { sftp in
            try await sftp.getRealPath(atPath: ".")
        }
    }

    // MARK: - Helpers

    private static func isDirectory(permissions: UInt32?) -> Bool {
        guard let permissions else { return false }
        // S_IFDIR = 0o040000 on POSIX
        return (permissions & 0o170000) == 0o040000
    }
}
