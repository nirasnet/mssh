import Foundation
import SwiftData
import Observation

@Observable
final class KeyManagerViewModel {
    var errorMessage: String?

    func generateKey(label: String, modelContext: ModelContext) {
        do {
            _ = try KeyManagementService.generateEd25519Key(label: label, modelContext: modelContext)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func importKey(label: String, pemText: String, modelContext: ModelContext) {
        do {
            _ = try KeyManagementService.importKey(label: label, pemText: pemText, modelContext: modelContext)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteKey(_ key: SSHKey, modelContext: ModelContext) {
        KeyManagementService.deleteKey(key, modelContext: modelContext)
    }

    func renameKey(_ key: SSHKey, to newLabel: String, modelContext: ModelContext) {
        let trimmed = newLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        key.label = trimmed
        try? modelContext.save()
    }
}
