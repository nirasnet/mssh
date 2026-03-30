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
        startObserving()
        checkiCloudAvailability()
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
            self?.lastSyncDate = Date()
            if self?.status != .notAvailable {
                self?.status = .synced
            }
        }

        observers = [willChange, remoteChange]
    }

    private func handleCloudKitEvent(_ notification: Notification) {
        // The event userInfo contains an NSPersistentCloudKitContainer.Event
        // We inspect it via key paths since the type is internal to CoreData.
        guard let event = notification.userInfo?["event"] as? NSObject else { return }

        let endDate = event.value(forKey: "endDate")
        let succeeded = (event.value(forKey: "succeeded") as? Bool) ?? false
        let errorValue = event.value(forKey: "error") as? NSError

        if endDate == nil {
            // Event is still in progress
            status = .syncing
        } else if let error = errorValue, !succeeded {
            status = .error(error.localizedDescription)
        } else {
            status = .synced
            lastSyncDate = Date()
        }
    }
}
