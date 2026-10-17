//
//  NoteAlertSubscription.swift
//  AppCasal
//

#if DEBUG
import CloudKit
import UserNotifications

/// Debug-only experiment (stage 1): visible alert for new notes through a documented
/// `CKDatabaseSubscription` scoped by `recordType`. Created only when the user taps
/// the button on the test screen; never created automatically.
///
/// Owner watches the private database (the shared zone lives there); the
/// participant watches the shared database. Uses its own subscription ID and
/// never touches the subscriptions created by `NSPersistentCloudKitContainer`.
/// Known limits to measure: it also fires for edits and deletions of notes,
/// CloudKit only excludes the originating device "when appropriate", and the
/// system may coalesce or delay pushes.
nonisolated enum NoteAlertSubscription {
    static let subscriptionID = "note-alerts-experiment-v1"
    /// Core Data prefixes mirrored record types with `CD_`.
    static let noteRecordType = "CD_Note"

    enum AlertError: LocalizedError {
        case notificationsDenied

        var errorDescription: String? {
            String(localized: "As notificações estão desativadas para o app.")
        }
    }

    static func database(for role: Member.Role, in container: CKContainer) -> CKDatabase {
        switch role {
        case .owner: container.privateCloudDatabase
        case .participant: container.sharedCloudDatabase
        }
    }

    static func register(for role: Member.Role, in container: CKContainer) async throws {
        let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
        guard granted else { throw AlertError.notificationsDenied }

        let subscription = CKDatabaseSubscription(subscriptionID: subscriptionID)
        subscription.recordType = noteRecordType
        let info = CKSubscription.NotificationInfo()
        info.title = String(localized: "Recadinho")
        info.alertBody = String(localized: "Você recebeu um recadinho.")
        info.soundName = "default"
        subscription.notificationInfo = info

        _ = try await database(for: role, in: container).save(subscription)
    }

    static func remove(for role: Member.Role, in container: CKContainer) async throws {
        _ = try await database(for: role, in: container).deleteSubscription(withID: subscriptionID)
    }
}
#endif
