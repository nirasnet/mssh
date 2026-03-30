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
}
