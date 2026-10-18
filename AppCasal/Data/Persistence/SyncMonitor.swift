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
    /// Local transactions saved after the last successful export; nil until an export
    /// succeeded in this session (otherwise every past change would count as pending).
    private(set) var pendingChanges: Int?
    private var lastSuccessfulExport: Date?
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
            if event.type == .export, event.succeeded, let end = event.endDate {
                lastSuccessfulExport = end
            }
            await refreshPendingChanges(in: container)
        }
    }

    /// Recounts pending local changes; call after local saves too.
    func refreshPendingChanges(in container: NSPersistentCloudKitContainer) async {
        guard let since = lastSuccessfulExport else { return }
        pendingChanges = await Self.countLocalTransactions(after: since, in: container)
    }

    /// Counts transactions written by this app (`transactionAuthor = "app"`) after `date`,
    /// using persistent history on a background context.
    private static func countLocalTransactions(after date: Date, in container: NSPersistentCloudKitContainer) async -> Int {
        let context = container.newBackgroundContext()
        return await context.perform {
            let request = NSPersistentHistoryChangeRequest.fetchHistory(after: date)
            request.resultType = .transactionsOnly
            guard let result = try? context.execute(request) as? NSPersistentHistoryResult,
                  let transactions = result.result as? [NSPersistentHistoryTransaction] else { return 0 }
            return transactions.filter { $0.author == "app" }.count
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

    /// Summary for the sync banner. Demo and missing accounts take precedence over events.
    func displayState(isDemo: Bool, accountStatus: AccountService.Status, isConnected: Bool = true) -> SyncDisplayState {
        if isDemo { return .demo }
        guard accountStatus == .available else { return .accountUnavailable }
        if !isConnected { return .offline(pending: pendingChanges) }
        if let pending = pendingChanges, pending > 0 { return .pending(pending) }
        guard let latest = entries.first else { return .upToDate }
        if !latest.isFinished { return .syncing }
        if !latest.succeeded { return .failed(latest.errorDescription ?? String(localized: "Erro desconhecido.")) }
        return .upToDate
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
