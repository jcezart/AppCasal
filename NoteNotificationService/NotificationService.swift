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

    private static let spaceEndedKey = "spaceEndedShownAt"
    private static let spaceEndedLock = NSLock()

    var isSpaceEnded: Bool {
        switch self {
        case .note(.spaceEnded), .answer(.spaceEnded, _), .game(.spaceEnded, _): true
        default: false
        }
    }

    func apply(to content: UNMutableNotificationContent, now: Date = .now) {
        // The three subscriptions all fire when the space ends: the first push says it,
        // the next ones (same process or not, shared defaults) arrive quietly.
        var isRepeat = false
        if isSpaceEnded {
            Self.spaceEndedLock.withLock {
                let defaults = UserDefaults.standard
                isRepeat = RemoteAlertPresentation.spaceEndedIsRepeat(lastShownAt: defaults.object(forKey: Self.spaceEndedKey) as? Date, now: now)
                if !isRepeat { defaults.set(now, forKey: Self.spaceEndedKey) }
            }
        }
        let presentation = switch self {
        case .note(let outcome): RemoteAlertPresentation.note(outcome, spaceEndedIsRepeat: isRepeat)
        case .answer(let outcome, let partnerName): RemoteAlertPresentation.answer(outcome, partnerName: partnerName, spaceEndedIsRepeat: isRepeat)
        case .game(let outcome, let partnerName): RemoteAlertPresentation.game(outcome, partnerName: partnerName, spaceEndedIsRepeat: isRepeat)
        }
        if let title = presentation.title { content.title = title }
        if let subtitle = presentation.subtitle { content.subtitle = subtitle }
        if let body = presentation.body { content.body = body }
        content.threadIdentifier = presentation.threadIdentifier
        if presentation.isQuiet {
            content.interruptionLevel = .passive
            content.sound = nil
        }
        if !presentation.userInfo.isEmpty {
            var userInfo = content.userInfo
            for (key, value) in presentation.userInfo { userInfo[key] = value }
            content.userInfo = userInfo
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
