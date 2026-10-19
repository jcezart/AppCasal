//
//  NotificationService.swift
//  NoteNotificationService
//

import CloudKit
import Foundation
import UserNotifications

/// Replaces the generic note alert ("Chegou um carinho pra você") with the text of the
/// partner's note, with its day and time as the subtitle. The CloudKit push carries no fields, so the note is fetched here.
/// When the push came from the shared space being deleted or no longer shared, says so
/// instead (an extension cannot hide a push without Apple's filtering entitlement).
/// When nothing can be found in time (no network, an edit of an old note, a deletion),
/// the generic alert is shown unchanged. Pushes of the answer alert subscription get
/// "<par> respondeu à pergunta do dia…" the same way, never the answer itself; pushes of
/// the game alert subscription get "Um novo quiz foi iniciado!…", never the choices.
final class NotificationService: UNNotificationServiceExtension {
    private let delivery = Delivery()

    override func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
    ) {
        let content = (request.content.mutableCopy() as? UNMutableNotificationContent) ?? UNMutableNotificationContent()
        let userInfo = request.content.userInfo
        let delivery = delivery
        if let scope = NoteAlertContent.databaseScope(of: userInfo) {
            delivery.start(content: content, handler: contentHandler)
            Task {
                let outcome = await PartnerNoteFetcher.outcome(in: scope)
                delivery.finish(.note(outcome))
            }
        } else if let scope = AnswerAlertContent.databaseScope(of: userInfo) {
            // The subscription carries the partner's name as the subtitle; it stays there
            // when nothing better is found in time.
            let partnerName = content.subtitle
            delivery.start(content: content, handler: contentHandler)
            Task {
                let outcome = await PartnerAnswerFetcher.outcome(in: scope)
                delivery.finish(.answer(outcome, partnerName: partnerName))
            }
        } else if let scope = GameAlertContent.databaseScope(of: userInfo) {
            let partnerName = content.subtitle
            content.subtitle = ""
            delivery.start(content: content, handler: contentHandler)
            Task {
                let outcome = await PartnerGameFetcher.outcome(in: scope)
                delivery.finish(.game(outcome, partnerName: partnerName))
            }
        } else {
            contentHandler(content)
        }
    }

    override func serviceExtensionTimeWillExpire() {
        delivery.finish(nil)
    }
}

/// What the fetch found, for the alert being delivered.
private enum AlertOutcome: Sendable {
    case note(NoteAlertOutcome)
    case answer(AnswerAlertOutcome, partnerName: String)
    case game(GameAlertOutcome, partnerName: String)

    func apply(to content: UNMutableNotificationContent) {
        switch self {
        case .note(.note(let note)):
            content.subtitle = NoteAlertContent.subtitle(for: note)
            content.body = NoteAlertContent.body(for: note)
        case .note(.spaceEnded), .answer(.spaceEnded, _), .game(.spaceEnded, _):
            content.title = NoteAlertContent.spaceEndedTitle
            content.subtitle = ""
            content.body = NoteAlertContent.spaceEndedBody
        case .answer(.event(let event), let partnerName):
            content.subtitle = AnswerAlertContent.subtitle(for: event) ?? ""
            content.body = AnswerAlertContent.body(for: event, partnerName: partnerName)
            var userInfo = content.userInfo
            userInfo[AnswerAlertContent.routeKey] = AnswerAlertContent.route(for: event)
            content.userInfo = userInfo
        case .game(.event(let event), let partnerName):
            content.body = GameAlertContent.body(for: event, partnerName: partnerName)
            var userInfo = content.userInfo
            userInfo[AnswerAlertContent.routeKey] = GameAlertContent.route
            content.userInfo = userInfo
        case .note(.unknown), .answer(.unknown, _), .game(.unknown, _):
            break
        }
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

    /// Nil: the system deadline came first, so the generic alert goes out unchanged.
    func finish(_ outcome: AlertOutcome?) {
        guard let taken = take() else { return }
        outcome?.apply(to: taken.content)
        taken.handler(taken.content)
    }

    private func take() -> Pending? {
        lock.withLock {
            defer { pending = nil }
            return pending
        }
    }
}
