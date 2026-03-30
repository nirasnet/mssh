import Foundation
import SwiftUI

struct SFTPFileItem: Identifiable, Sendable {
    let id = UUID()
    let name: String
    let path: String
    let isDirectory: Bool
    let size: UInt64?
    let modifiedDate: Date?
    let permissions: UInt32?

    var formattedSize: String {
        guard let size else { return "--" }
        if size < 1024 {
            return "\(size) B"
        } else if size < 1024 * 1024 {
            return String(format: "%.1f KB", Double(size) / 1024)
        } else if size < 1024 * 1024 * 1024 {
            return String(format: "%.1f MB", Double(size) / (1024 * 1024))
        } else {
            return String(format: "%.2f GB", Double(size) / (1024 * 1024 * 1024))
        }
    }

    var formattedDate: String {
        guard let modifiedDate else { return "--" }
        let formatter = DateFormatter()
        let calendar = Calendar.current
        if calendar.isDateInToday(modifiedDate) {
            formatter.dateFormat = "HH:mm"
        } else if calendar.isDate(modifiedDate, equalTo: Date(), toGranularity: .year) {
            formatter.dateFormat = "MMM d HH:mm"
        } else {
            formatter.dateFormat = "MMM d, yyyy"
        }
        return formatter.string(from: modifiedDate)
    }

    var formattedPermissions: String {
        guard let permissions else { return "---" }
        let octal = String(permissions & 0o7777, radix: 8)
        return octal
    }

    var iconName: String {
        if isDirectory {
            return "folder.fill"
        }
        let ext = (name as NSString).pathExtension.lowercased()
        switch ext {
        case "txt", "md", "log":
            return "doc.text.fill"
        case "jpg", "jpeg", "png", "gif", "bmp", "svg", "webp":
            return "photo.fill"
        case "mp4", "mov", "avi", "mkv":
            return "film.fill"
        case "mp3", "wav", "aac", "flac":
            return "music.note"
        case "zip", "tar", "gz", "bz2", "xz", "7z":
            return "doc.zipper"
        case "pdf":
            return "doc.richtext.fill"
        case "swift", "py", "js", "ts", "c", "cpp", "h", "rs", "go", "rb", "java":
            return "chevron.left.forwardslash.chevron.right"
        case "json", "xml", "yaml", "yml", "toml", "plist":
            return "doc.badge.gearshape.fill"
        case "sh", "bash", "zsh":
            return "terminal.fill"
        default:
            return "doc.fill"
        }
    }

    var iconColor: Color {
        if isDirectory {
            return .blue
        }
        let ext = (name as NSString).pathExtension.lowercased()
        switch ext {
        case "jpg", "jpeg", "png", "gif", "bmp", "svg", "webp":
            return .green
        case "mp4", "mov", "avi", "mkv":
            return .purple
        case "mp3", "wav", "aac", "flac":
            return .pink
        case "zip", "tar", "gz", "bz2", "xz", "7z":
            return .orange
        default:
            return .secondary
        }
    }
}
