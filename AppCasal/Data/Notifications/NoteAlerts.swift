//
//  NoteAlerts.swift
//  AppCasal
//

import CloudKit
import Foundation
import Observation

/// Push alert when the partner leaves a note, through a `CKDatabaseSubscription` scoped
/// to the note record type.
///
/// The owner watches the private database (the shared zone lives there); the
/// participant watches the shared database. Uses its own subscription ID and never
/// touches the subscriptions created by `NSPersistentCloudKitContainer`.
/// Known limits (validate on two iPhones, N1–N6): it also fires for edits and
/// deletions of notes, CloudKit only skips the originating device "when appropriate",
/// and the system may coalesce or delay pushes. Never promise immediate delivery.
@Observable
final class NoteAlerts {
    nonisolated static let subscriptionID = NoteAlertContent.subscriptionID
    /// Core Data prefixes mirrored record types with `CD_`.
    static let noteRecordType = NoteAlertContent.recordType
    /// Created by the stage 1 debug experiment; removed so alerts do not arrive twice.
    static let legacySubscriptionIDs = ["note-alerts-experiment-v1"]
    private static let enabledKey = "notifications.notes.enabled"

    /// Personal preference, on by default. Only takes effect with notification permission.
    var isEnabled: Bool {
        didSet { defaults.set(isEnabled, forKey: Self.enabledKey) }
    }
    private(set) var lastError: String?

    @ObservationIgnored private let defaults: UserDefaults
    /// What this launch already saved, so remote changes do not resave it.
    @ObservationIgnored private var registered: String?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        isEnabled = defaults.object(forKey: Self.enabledKey) as? Bool ?? true
    }

    static func database(for role: Member.Role, in container: CKContainer) -> CKDatabase {
        switch role {
        case .owner: container.privateCloudDatabase
        case .participant: container.sharedCloudDatabase
        }
    }

    static func makeSubscription(partnerName: String) -> CKDatabaseSubscription {
        let subscription = CKDatabaseSubscription(subscriptionID: subscriptionID)
        subscription.recordType = noteRecordType
        let info = CKSubscription.NotificationInfo()
        info.title = partnerName.isEmpty
            ? String(localized: "Novo recadinho")
            : String(localized: "Recadinho de \(partnerName)")
        // Shown as is when the extension cannot fetch the note in time.
        info.alertBody = String(localized: "Chegou um carinho pra você. Toque para ler.")
        info.soundName = "default"
        // Lets NoteNotificationService replace the body with the note's text.
        info.shouldSendMutableContent = true
        subscription.notificationInfo = info
        return subscription
    }

    /// Saves or removes the subscription to match the preference, the permission and
    /// whether the partner already joined. Network errors are kept, not thrown: the
    /// next launch or data change tries again.
    func update(role: Member.Role, partnerName: String?, allowed: Bool, container: CKContainer) async {
        let database = Self.database(for: role, in: container)
        guard isEnabled, allowed, let partnerName else {
            guard registered != "removed" else { return }
            do {
                _ = try await database.modifySubscriptions(saving: [], deleting: [Self.subscriptionID])
                registered = "removed"
            } catch {
                lastError = error.localizedDescription
            }
            return
        }
        let signature = "\(role)|\(partnerName)"
        guard registered != signature else { return }
        do {
            let (saved, _) = try await database.modifySubscriptions(
                saving: [Self.makeSubscription(partnerName: partnerName)],
                deleting: Self.legacySubscriptionIDs
            )
            if case .failure(let error) = saved[Self.subscriptionID] { throw error }
            registered = signature
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// Removes the subscription from both databases, for when there is no space.
    func removeEverywhere(container: CKContainer) async {
        guard registered != "removed" else { return }
        do {
            for database in [container.privateCloudDatabase, container.sharedCloudDatabase] {
                _ = try await database.modifySubscriptions(saving: [], deleting: [Self.subscriptionID])
            }
            registered = "removed"
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// True when a remote notification came from this subscription.
    nonisolated static func isNoteAlert(_ userInfo: [AnyHashable: Any]) -> Bool {
        CKNotification(fromRemoteNotificationDictionary: userInfo)?.subscriptionID == subscriptionID
    }
}
