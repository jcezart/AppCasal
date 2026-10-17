//
//  SyncMonitor.swift
//  AppCasal
//

import CoreData
import Observation

/// Keeps the most recent CloudKit mirroring events for diagnostics.
@Observable
final class SyncMonitor {
    struct Entry: Identifiable {
        let id: UUID
        let kind: String
        let storeName: String
        let succeeded: Bool
        let isFinished: Bool
        let errorDescription: String?
        let date: Date
    }

    private(set) var entries: [Entry] = []
    private let limit = 20

    /// Records events from `container` until cancelled.
    func observe(_ container: NSPersistentCloudKitContainer) async {
        let events = NotificationCenter.default.notifications(
            named: NSPersistentCloudKitContainer.eventChangedNotification,
            object: container
        )
        for await notification in events {
            guard let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                as? NSPersistentCloudKitContainer.Event else { continue }
            record(event, storeName: Self.storeName(for: event, in: container))
        }
    }

    private func record(_ event: NSPersistentCloudKitContainer.Event, storeName: String) {
        let entry = Entry(
            id: event.identifier,
            kind: Self.describe(event.type),
            storeName: storeName,
            succeeded: event.succeeded,
            isFinished: event.endDate != nil,
            errorDescription: event.error?.localizedDescription,
            date: event.endDate ?? event.startDate
        )
        // Start and end of an event share the identifier; keep the latest state.
        entries.removeAll { $0.id == entry.id }
        entries.insert(entry, at: 0)
        if entries.count > limit {
            entries.removeLast(entries.count - limit)
        }
    }

    private static func storeName(for event: NSPersistentCloudKitContainer.Event, in container: NSPersistentCloudKitContainer) -> String {
        let store = container.persistentStoreCoordinator.persistentStores.first { $0.identifier == event.storeIdentifier }
        return store?.url?.deletingPathExtension().lastPathComponent ?? "?"
    }

    private static func describe(_ type: NSPersistentCloudKitContainer.EventType) -> String {
        switch type {
        case .setup: "setup"
        case .import: "import"
        case .export: "export"
        @unknown default: "other"
        }
    }
}
