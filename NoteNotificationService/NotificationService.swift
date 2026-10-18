//
//  NotificationService.swift
//  NoteNotificationService
//

import CloudKit
import Foundation
import UserNotifications

/// Replaces the generic note alert ("Chegou um carinho pra você") with the text of the
/// partner's note, with its day and time as the subtitle. The CloudKit push carries no fields, so the note is fetched here.
/// When it cannot be found in time (no network, an edit of an old note, a deletion),
/// the generic alert is shown unchanged.
final class NotificationService: UNNotificationServiceExtension {
    private let delivery = Delivery()

    override func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
    ) {
        let content = (request.content.mutableCopy() as? UNMutableNotificationContent) ?? UNMutableNotificationContent()
        guard let scope = NoteAlertContent.databaseScope(of: request.content.userInfo) else {
            contentHandler(content)
            return
        }
        delivery.start(content: content, handler: contentHandler)
        let delivery = delivery
        Task {
            let note = await PartnerNoteFetcher.latestNote(in: scope)
            delivery.finish(note: note)
        }
    }

    override func serviceExtensionTimeWillExpire() {
        delivery.finish(note: nil)
    }
}

/// The pending alert, delivered once by whichever finishes first: the fetch or the
/// system deadline (`serviceExtensionTimeWillExpire`, possibly on another thread).
///
/// `@unchecked Sendable` (justified): the content handler and the mutable content
/// that the system hands over are not `Sendable`, yet must be reachable from the fetch
/// task and from the deadline callback. Every access to them goes through `lock`,
/// and `take()` hands them out exactly once, so they are never used concurrently.
private final class Delivery: @unchecked Sendable {
    private struct Pending {
        let handler: (UNNotificationContent) -> Void
        let content: UNMutableNotificationContent
    }

    private let lock = NSLock()
    private var pending: Pending?

    func start(content: UNMutableNotificationContent, handler: @escaping (UNNotificationContent) -> Void) {
        lock.withLock { pending = Pending(handler: handler, content: content) }
    }

    func finish(note: NoteAlertContent.Note?) {
        guard let taken = take() else { return }
        if let note {
            taken.content.subtitle = NoteAlertContent.subtitle(for: note)
            taken.content.body = NoteAlertContent.body(for: note)
        }
        taken.handler(taken.content)
    }

    private func take() -> Pending? {
        lock.withLock {
            defer { pending = nil }
            return pending
        }
    }
}
