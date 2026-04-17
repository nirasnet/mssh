import Foundation
import SwiftUI
import CoreData

enum SyncStatus: Equatable {
    case notStarted
    case syncing
    case synced
    case error(String)
    case notAvailable

    var label: String {
        switch self {
        case .notStarted:
            return "Waiting"
        case .syncing:
            return "Syncing..."
        case .synced:
            return "Synced"
        case .error(let message):
            return "Error: \(message)"
        case .notAvailable:
            return "iCloud not available"
        }
    }

    var systemImage: String {
        switch self {
        case .notStarted:
            return "icloud"
        case .syncing:
            return "arrow.triangle.2.circlepath.icloud"
        case .synced:
            return "checkmark.icloud"
        case .error:
            return "exclamationmark.icloud"
        case .notAvailable:
            return "icloud.slash"
        }
    }
}

@Observable
final class iCloudSyncService {
    private(set) var status: SyncStatus = .notStarted
    private(set) var lastSyncDate: Date?

    private var observers: [Any] = []

    init() {
        // Defer observer setup + availability check past the first
        // SwiftUI layout cycle. On macOS 26.3 an @Observable mutation
        // during NSHostingView's initial window-sizing animation triggers
        // recursive _informContainerThatSubviewsNeedUpdateConstraints →
        // SIGABRT. Posting async ensures the first layout pass finishes
        // before any status property changes fire.
        DispatchQueue.main.async { [weak self] in
            self?.startObserving()
            self?.checkiCloudAvailability()
        }
    }

    deinit {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
    }

    private func checkiCloudAvailability() {
        FileManager.default.ubiquityIdentityToken == nil
            ? (status = .notAvailable)
            : ()
    }

    private func startObserving() {
        // NSPersistentCloudKitContainer posts these notifications when SwiftData uses CloudKit sync.
        let willChange = NotificationCenter.default.addObserver(
            forName: Notification.Name("NSPersistentCloudKitContainerEventChangedNotification"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleCloudKitEvent(notification)
        }

        // Also observe the standard Core Data remote change notification
        let remoteChange = NotificationCenter.default.addObserver(
            forName: .NSPersistentStoreRemoteChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            DispatchQueue.main.async {
                self?.lastSyncDate = Date()
                if self?.status != .notAvailable {
                    self?.status = .synced
                }
            }
        }

        observers = [willChange, remoteChange]
    }

    private func handleCloudKitEvent(_ notification: Notification) {
        guard let event = notification.userInfo?["event"] as? NSObject else { return }

        let endDate = event.value(forKey: "endDate")
        let succeeded = (event.value(forKey: "succeeded") as? Bool) ?? false
        let errorValue = event.value(forKey: "error") as? NSError

        // Defer property mutations so they never land inside an
        // NSHostingView layout pass (macOS 26.3 crash workaround).
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if endDate == nil {
                self.status = .syncing
            } else if let error = errorValue, !succeeded {
                self.status = .error(error.localizedDescription)
            } else {
                self.status = .synced
                self.lastSyncDate = Date()
            }
        }
    }
}
