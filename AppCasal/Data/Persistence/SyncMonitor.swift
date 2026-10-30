//
//  SyncMonitor.swift
//  AppCasal
//

import CloudKit
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
        /// The iCloud storage that holds the space is full: the owner's, for both partners.
        let isQuotaExceeded: Bool
        let date: Date
    }

    private(set) var entries: [Entry] = []
    /// Local transactions saved after the last successful export; nil until an export
    /// succeeded in this session (otherwise every past change would count as pending).
    private(set) var pendingChanges: Int?
    private var lastSuccessfulExport: Date?
    private var didPurgeHistory = false
    /// Persistent history older than this is deleted (see `purgeHistory`).
    static let historyRetention: TimeInterval = 30 * 24 * 60 * 60
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
                if !didPurgeHistory {
                    didPurgeHistory = true
                    await Self.purgeHistory(before: end.addingTimeInterval(-Self.historyRetention), in: container)
                }
            }
            await refreshPendingChanges(in: container)
        }
    }

    /// Recounts pending local changes; call after local saves too.
    func refreshPendingChanges(in container: NSPersistentCloudKitContainer) async {
        guard let since = lastSuccessfulExport else { return }
        pendingChanges = await Self.countLocalTransactions(after: since, in: container)
    }

    /// Deletes persistent history before `date`, once per session and only after an export
    /// succeeded, so what mirroring still has to send is weeks newer. Without it the
    /// history grows with every change for the life of the app. Mirroring keeps its own
    /// position in the history; a device offline for longer than the retention is the case
    /// to watch (Core Data then has to rescan instead of reading the history).
    static func purgeHistory(before date: Date, in container: NSPersistentContainer) async {
        let context = container.newBackgroundContext()
        await context.perform {
            _ = try? context.execute(NSPersistentHistoryChangeRequest.deleteHistory(before: date))
        }
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
            isQuotaExceeded: Self.isQuotaExceeded(event.error),
            date: event.endDate ?? event.startDate
        )
        // Start and end of an event share the identifier; keep the latest state.
        entries.removeAll { $0.id == entry.id }
        entries.insert(entry, at: 0)
        if entries.count > limit {
            entries.removeLast(entries.count - limit)
        }
    }

    /// Whether a mirroring error comes from full iCloud storage, directly, inside a partial
    /// failure or as the underlying error Core Data wraps.
    nonisolated static func isQuotaExceeded(_ error: (any Error)?) -> Bool {
        guard let error else { return false }
        if let ckError = error as? CKError {
            if ckError.code == .quotaExceeded { return true }
            if ckError.code == .partialFailure {
                return ckError.partialErrorsByItemID?.values.contains { isQuotaExceeded($0) } ?? false
            }
        }
        return isQuotaExceeded((error as NSError).userInfo[NSUnderlyingErrorKey] as? any Error)
    }

    /// Summary for the sync banner. Demo and missing accounts take precedence over events.
    /// `isOwner`: the space lives in the owner's iCloud, so a full storage reads differently
    /// for the partner.
    func displayState(isDemo: Bool, accountStatus: AccountService.Status, isConnected: Bool = true, isOwner: Bool = true) -> SyncDisplayState {
        if isDemo { return .demo }
        guard accountStatus == .available else { return .accountUnavailable }
        if !isConnected { return .offline(pending: pendingChanges) }
        if let pending = pendingChanges, pending > 0 { return .pending(pending) }
        guard let latest = entries.first else { return .upToDate }
        if !latest.isFinished { return .syncing }
        if !latest.succeeded, latest.isQuotaExceeded { return .iCloudFull(isOwner: isOwner) }
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
