//
//  AnswerAlerts.swift
//  AppCasal
//

import CloudKit
import Foundation
import Observation

/// Push alert when the partner answers the daily question ("… está esperando a sua
/// resposta"), through a `CKDatabaseSubscription` scoped to the daily answer record
/// type. Same databases and limits as `NoteAlerts`: the owner watches the private
/// database, the participant the shared one; own subscription ID, never the ones of
/// `NSPersistentCloudKitContainer`.
///
/// Known limits (validate on two iPhones, H11–H13): the push also fires for reactions
/// and when the space ends; the extension then says so instead (it cannot hide an
/// alert without Apple's filtering entitlement). CloudKit only skips the originating
/// device "when appropriate", and pushes can be coalesced or delayed. Never promise
/// immediate delivery.
@Observable
final class AnswerAlerts {
    nonisolated static let subscriptionID = AnswerAlertContent.subscriptionID
    private static let enabledKey = "notifications.answers.enabled"

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

    static func makeSubscription(partnerName: String) -> CKDatabaseSubscription {
        let subscription = CKDatabaseSubscription(subscriptionID: subscriptionID)
        subscription.recordType = AnswerAlertContent.recordType
        let info = CKSubscription.NotificationInfo()
        info.title = AnswerAlertContent.title
        // The extension reads the partner's name from here and replaces it with the question.
        info.subtitle = partnerName
        info.alertBody = AnswerAlertContent.fallbackBody
        info.soundName = "default"
        info.shouldSendMutableContent = true
        subscription.notificationInfo = info
        return subscription
    }

    /// Saves or removes the subscription to match the preference, the permission and
    /// whether the partner already joined. Network errors are kept, not thrown: the
    /// next launch or data change tries again.
    func update(role: Member.Role, partnerName: String?, allowed: Bool, container: CKContainer) async {
        let database = NoteAlerts.database(for: role, in: container)
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
            let (saved, _) = try await database.modifySubscriptions(saving: [Self.makeSubscription(partnerName: partnerName)], deleting: [])
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
    nonisolated static func isAnswerAlert(_ userInfo: [AnyHashable: Any]) -> Bool {
        CKNotification(fromRemoteNotificationDictionary: userInfo)?.subscriptionID == subscriptionID
    }
}
