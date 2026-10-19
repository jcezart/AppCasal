//
//  RemoteAlertPresentation.swift
//  AppCasal
//
//  Compiled in the app and in the NoteNotificationService extension.
//

import Foundation

/// What a push from one of the alert subscriptions turned out to be, once the
/// extension fetched the changes. `irrelevant`: the fetch worked and nothing new from the
/// partner explains the push (a deletion, an edit of an old item, this account's own
/// change). `unknown`: the fetch failed or ran out of time, so the push may still be news.
nonisolated enum NoteAlertOutcome: Sendable {
    case note(NoteAlertContent.Note)
    case spaceEnded
    case irrelevant
    case unknown
}

nonisolated enum AnswerAlertOutcome: Sendable {
    case event(AnswerAlertContent.Event)
    case spaceEnded
    case irrelevant
    case unknown
}

nonisolated enum GameAlertOutcome: Sendable {
    case event(GameAlertContent.Event)
    case spaceEnded
    case irrelevant
    case unknown
}

/// The single place deciding how an alert subscription push is shown. The extension
/// cannot drop a push (that needs Apple's filtering entitlement), so pushes that are not
/// news are made quiet instead: delivered to Notification Center without sound or
/// banner (`passive`), grouped by thread.
nonisolated struct RemoteAlertPresentation: Equatable, Sendable {
    /// Nil keeps the subscription's text.
    var title: String?
    var subtitle: String?
    var body: String?
    /// Passive and silent: news the person does not need to act on, or a repeat.
    var isQuiet = false
    var threadIdentifier: String
    /// Added to the alert's user info (route and what makes it obsolete).
    var userInfo: [String: String] = [:]

    /// User info keys: the day key (daily question) or round ID (quiz) whose answer makes
    /// an alert pointless. Set on question reminders and on "waiting for you" alerts.
    static let obsoleteDayKey = "momentsObsoleteWhenAnswered"
    static let obsoleteRoundKey = "momentsObsoleteWhenPlayed"

    /// Several subscriptions fire when the space ends; only the first says it out loud.
    static let spaceEndedRepeatWindow: TimeInterval = 30 * 60

    static func spaceEndedIsRepeat(lastShownAt: Date?, now: Date) -> Bool {
        guard let lastShownAt else { return false }
        return abs(now.timeIntervalSince(lastShownAt)) < spaceEndedRepeatWindow
    }

    private static func spaceEnded(isRepeat: Bool) -> RemoteAlertPresentation {
        RemoteAlertPresentation(
            title: NoteAlertContent.spaceEndedTitle,
            subtitle: "",
            body: NoteAlertContent.spaceEndedBody,
            isQuiet: isRepeat,
            threadIdentifier: "space"
        )
    }

    static func note(_ outcome: NoteAlertOutcome, spaceEndedIsRepeat: Bool) -> RemoteAlertPresentation {
        switch outcome {
        case .note(let note):
            return RemoteAlertPresentation(subtitle: NoteAlertContent.subtitle(for: note), body: NoteAlertContent.body(for: note), threadIdentifier: "notes")
        case .spaceEnded:
            return spaceEnded(isRepeat: spaceEndedIsRepeat)
        case .irrelevant:
            return RemoteAlertPresentation(body: String(localized: "Os recadinhos de vocês foram atualizados."), isQuiet: true, threadIdentifier: "notes")
        case .unknown:
            return RemoteAlertPresentation(threadIdentifier: "notes")
        }
    }

    static func answer(_ outcome: AnswerAlertOutcome, partnerName: String, spaceEndedIsRepeat: Bool) -> RemoteAlertPresentation {
        switch outcome {
        case .event(let event):
            var userInfo = [AnswerAlertContent.routeKey: AnswerAlertContent.route(for: event)]
            var isQuiet = false
            switch event {
            case .partnerAnswered(let dayKey, _, true):
                // Pointless once this person answers that day.
                userInfo[obsoleteDayKey] = dayKey
            case .partnerAnswered:
                break
            case .partnerReacted, .ownAnswer:
                isQuiet = true
            }
            return RemoteAlertPresentation(
                subtitle: AnswerAlertContent.subtitle(for: event) ?? "",
                body: AnswerAlertContent.body(for: event, partnerName: partnerName),
                isQuiet: isQuiet,
                threadIdentifier: "moments",
                userInfo: userInfo
            )
        case .spaceEnded:
            return spaceEnded(isRepeat: spaceEndedIsRepeat)
        case .irrelevant:
            return RemoteAlertPresentation(subtitle: "", body: String(localized: "A pergunta do dia foi atualizada."), isQuiet: true, threadIdentifier: "moments", userInfo: [AnswerAlertContent.routeKey: "explore"])
        case .unknown:
            return RemoteAlertPresentation(threadIdentifier: "moments")
        }
    }

    static func game(_ outcome: GameAlertOutcome, partnerName: String, spaceEndedIsRepeat: Bool) -> RemoteAlertPresentation {
        switch outcome {
        case .event(let event):
            var userInfo = [AnswerAlertContent.routeKey: GameAlertContent.route]
            var isQuiet = false
            switch event {
            case .partnerFinished(let roundID, true):
                userInfo[obsoleteRoundKey] = roundID
            case .partnerFinished:
                break
            case .ownFinished:
                isQuiet = true
            }
            return RemoteAlertPresentation(
                subtitle: "",
                body: GameAlertContent.body(for: event, partnerName: partnerName),
                isQuiet: isQuiet,
                threadIdentifier: "moments",
                userInfo: userInfo
            )
        case .spaceEnded:
            return spaceEnded(isRepeat: spaceEndedIsRepeat)
        case .irrelevant:
            return RemoteAlertPresentation(subtitle: "", body: String(localized: "O quiz de vocês foi atualizado."), isQuiet: true, threadIdentifier: "moments", userInfo: [AnswerAlertContent.routeKey: GameAlertContent.route])
        case .unknown:
            return RemoteAlertPresentation(threadIdentifier: "moments")
        }
    }
}
